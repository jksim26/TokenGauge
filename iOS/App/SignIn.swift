import AuthenticationServices
import CryptoKit
import Network
import SwiftUI
import WebKit

/// Shows a provider's own sign-in page and hands back that site's cookies once the session cookie appears.
/// The page uses the app's own persistent cookie store, so a Google (or other) sign-in done once is
/// remembered for the next provider and the next time. The caller keeps only what it needs, in the Keychain.
struct CookieSignIn: UIViewRepresentable {
    let url: URL
    let cookieName: String
    let domain: String
    let onCookies: ([String: String]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        // Identify as Safari: some sign-in providers refuse pages that look like an embedded web view.
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
        view.load(URLRequest(url: url))
        context.coordinator.cookiesDidChange(in: configuration.websiteDataStore.httpCookieStore) // already signed in from earlier
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKHTTPCookieStoreObserver, WKUIDelegate {
        private let parent: CookieSignIn
        private var delivered = false
        init(_ parent: CookieSignIn) { self.parent = parent }
        func cookiesDidChange(in store: WKHTTPCookieStore) {
            store.getAllCookies { cookies in
                let site = cookies.filter { $0.domain == self.parent.domain || $0.domain.hasSuffix("." + self.parent.domain) }
                guard !self.delivered, site.contains(where: { $0.name == self.parent.cookieName && !$0.value.isEmpty }) else { return }
                self.delivered = true
                self.parent.onCookies(Dictionary(site.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first }))
            }
        }
        // Sign-in pop-ups (window.open, target=_blank) load in the same view instead of being dropped.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            webView.load(action.request)
            return nil
        }
    }
}

/// OAuth sign-in (PKCE) through the provider CLI's public client, in the system sign-in sheet. The sheet
/// shares Safari's cookies and saved passwords, so an account already signed in there is one tap.
/// These clients only redirect to http://localhost, so the app listens on that loopback port meanwhile.
@MainActor
final class LoopbackSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var continuation: CheckedContinuation<String, Error>?
    private var listener: NWListener?
    private var web: ASWebAuthenticationSession?

    static func codex() async throws {
        let verifier = random(), state = random()
        let challenge = encode(Data(SHA256.hash(data: Data(verifier.utf8))))
        let code = try await LoopbackSignIn().code(url: UsageService.codexAuthorizeURL(challenge: challenge, state: state), state: state, port: 1455, path: "/auth/callback")
        try await UsageService.codexExchange(code: code, verifier: verifier)
    }
    static func claude() async throws {
        let verifier = random(), state = random()
        let challenge = encode(Data(SHA256.hash(data: Data(verifier.utf8))))
        let code = try await LoopbackSignIn().code(url: UsageService.claudeAuthorizeURL(challenge: challenge, state: state), state: state, port: UsageService.claudePort, path: "/callback")
        try await UsageService.claudeExchange(code: code, verifier: verifier, state: state)
    }
    /// Forgets a site's web session in the in-app browser (other sites, such as Google, stay signed in).
    static func clearWebSession(domain: String) async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await store.allCookies() where cookie.domain == domain || cookie.domain.hasSuffix("." + domain) { await store.deleteCookie(cookie) }
    }
    private func code(url: URL, state: String, port: UInt16, path: String) async throws -> String {
        let parameters = NWParameters.tcp
        // Bind to 127.0.0.1 only, as the Codex CLI does, so nothing else on the network can reach it.
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                let outcome = Result { try UsageParsing.oauthCallbackCode(request: String(decoding: data ?? Data(), as: UTF8.self), state: state, path: path) }
                let (status, body): (String, String)
                switch outcome {
                case .success(.some): (status, body) = ("200 OK", "Signed in. Return to Token Gauge.")
                case .success(.none): (status, body) = ("404 Not Found", "")
                case .failure: (status, body) = ("400 Bad Request", "Sign-in failed. Close this page and try again.")
                }
                let reply = "HTTP/1.1 \(status)\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
                Task { @MainActor in
                    switch outcome {
                    case .success(.some(let code)): self?.finish(.success(code))
                    case .success(.none): break
                    case .failure(let error): self?.finish(.failure(error))
                    }
                }
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state { Task { @MainActor in self?.finish(.failure(error)) } }
        }
        listener.start(queue: .main)
        // No callback scheme: the redirect reaches the listener above, which then dismisses the sheet.
        let web = ASWebAuthenticationSession(url: url, callbackURLScheme: nil) { [weak self] _, error in
            Task { @MainActor in self?.finish(.failure(error ?? CancellationError())) }
        }
        web.presentationContextProvider = self
        web.prefersEphemeralWebBrowserSession = false // reuse Safari's existing sign-in and saved passwords
        self.listener = listener
        self.web = web
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if !web.start() { finish(.failure(CancellationError())) }
        }
    }
    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        listener?.cancel()
        web?.cancel()
        continuation.resume(with: result)
    }
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
        }
    }
    private static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return encode(Data(bytes))
    }
    private static func encode(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
