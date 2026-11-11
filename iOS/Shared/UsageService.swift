import Foundation

/// Fetches each provider's usage with the sign-in stored on this phone. These are the providers' own
/// unofficial usage endpoints, the same ones their apps use; no prompt is ever sent to a model.
enum UsageService {
    struct Failure: Error { let message: String }
    static let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann" // the Codex CLI's public OAuth client
    static let codexRedirect = "http://localhost:1455/auth/callback"

    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }()
    private static func send(_ request: URLRequest) async throws -> (data: Data, status: Int) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, data.count <= 2 * 1024 * 1024 else { throw Failure(message: "Unreadable response") }
        return (data, http.statusCode)
    }
    private static func request(_ url: String, headers: [String: String]) throws -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("TokenGauge/1.0", forHTTPHeaderField: "User-Agent")
        for (field, value) in headers {
            guard !value.contains("\n"), !value.contains("\r") else { throw Failure(message: "Sign in again") }
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
    private static func check(_ status: Int, _ provider: Provider, data: Data = Data()) throws {
        switch status {
        case 200..<300: return
        case 401: throw Failure(message: "Sign in to \(provider.title) again")
        case 403:
            let challenge = String(decoding: data.prefix(4096), as: UTF8.self).range(of: "cf-chl|Just a moment|challenge-platform", options: .regularExpression) != nil
            throw Failure(message: challenge ? "\(provider.title) blocked the check with a security challenge" : "Sign in to \(provider.title) again")
        case 429: throw Failure(message: "\(provider.title) rate-limited usage checks; retrying later")
        default: throw Failure(message: "\(provider.title) usage unavailable (HTTP \(status))")
        }
    }

    // MARK: Claude (sign-in through Claude Code's OAuth client; a claude.ai web session is the fallback)
    static let claudeClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e" // Claude Code's public OAuth client
    static let claudePort: UInt16 = 54545
    static let claudeRedirect = "http://localhost:54545/callback"
    static func claudeAuthorizeURL(challenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://claude.ai/oauth/authorize")!
        components.queryItems = [
            ("code", "true"), ("client_id", claudeClientID), ("response_type", "code"), ("redirect_uri", claudeRedirect),
            ("scope", "user:profile"), // enough to read usage; no permission to run models
            ("code_challenge", challenge), ("code_challenge_method", "S256"), ("state", state),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url!
    }
    static func claudeExchange(code: String, verifier: String, state: String) async throws {
        _ = try await claudeToken(["grant_type": "authorization_code", "code": code, "redirect_uri": claudeRedirect, "code_verifier": verifier, "state": state])
    }
    private static func claudeToken(_ parameters: [String: String]) async throws -> String {
        var request = try request("https://console.anthropic.com/v1/oauth/token", headers: ["Content-Type": "application/json"])
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters.merging(["client_id": claudeClientID]) { first, _ in first })
        let result = try await send(request)
        guard (200..<300).contains(result.status),
              let body = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any],
              let access = body["access_token"] as? String, !access.isEmpty else {
            throw Failure(message: (400..<500).contains(result.status) ? "Sign in to Claude again" : "Claude sign-in could not be renewed")
        }
        Store.set(access, for: .claudeAccess)
        if let refresh = body["refresh_token"] as? String, !refresh.isEmpty { Store.set(refresh, for: .claudeRefresh) }
        return access
    }
    private static func claudeOAuth(_ access: String) async throws -> [Quota] {
        try await Store.locked("claude") {
            var access = Store.secret(.claudeAccess) ?? access
            func usage() async throws -> (data: Data, status: Int) {
                try await send(request("https://api.anthropic.com/api/oauth/usage", headers: ["Authorization": "Bearer \(access)", "anthropic-beta": "oauth-2025-04-20"]))
            }
            var result = try await usage()
            if result.status == 401, let refresh = Store.secret(.claudeRefresh) {
                access = try await claudeToken(["grant_type": "refresh_token", "refresh_token": refresh])
                result = try await usage()
            }
            try check(result.status, .claude, data: result.data)
            return try UsageParsing.claude(result.data)
        }
    }
    static func claude() async throws -> [Quota] {
        if let access = Store.secret(.claudeAccess) { return try await claudeOAuth(access) }
        guard let cookies = Store.secret(.claudeSession) else { throw Failure(message: "Not signed in") }
        func get(_ path: String) async throws -> Data {
            let result = try await send(request("https://claude.ai" + path, headers: ["Cookie": cookies]))
            try check(result.status, .claude, data: result.data)
            return result.data
        }
        if let organization = Store.secret(.claudeOrganization), organization.range(of: "^[a-fA-F0-9-]{36}$", options: .regularExpression) != nil {
            do { return try UsageParsing.claude(await get("/api/organizations/\(organization)/usage")) }
            catch { Store.set(nil, for: .claudeOrganization); throw error } // re-resolve the organization next time
        }
        let organization = try UsageParsing.claudeOrganization(await get("/api/organizations"))
        Store.set(organization, for: .claudeOrganization)
        return try UsageParsing.claude(await get("/api/organizations/\(organization)/usage"))
    }

    // MARK: Codex (ChatGPT sign-in through the Codex CLI's OAuth client)
    static func codex() async throws -> [Quota] {
        try await Store.locked("codex") {
            guard var access = Store.secret(.codexAccess) else { throw Failure(message: "Not signed in") }
            if let expiry = UsageParsing.jwtExpiry(access), expiry - Date().timeIntervalSince1970 < 300 { access = try await renewCodex() }
            func usage() async throws -> (data: Data, status: Int) {
                try await send(request("https://chatgpt.com/backend-api/wham/usage", headers: ["Authorization": "Bearer \(access)"]))
            }
            var result = try await usage()
            if result.status == 401, Store.secret(.codexRefresh) != nil {
                access = try await renewCodex()
                result = try await usage()
            }
            try check(result.status, .codex, data: result.data)
            return try UsageParsing.codex(result.data)
        }
    }
    private static func renewCodex() async throws -> String {
        guard let refresh = Store.secret(.codexRefresh) else { throw Failure(message: "Sign in to Codex again") }
        return try await codexToken(["grant_type": "refresh_token", "refresh_token": refresh, "scope": "openid profile email"], json: true)
    }
    static func codexAuthorizeURL(challenge: String, state: String) -> URL {
        var components = URLComponents(string: "https://auth.openai.com/oauth/authorize")!
        components.queryItems = [
            ("response_type", "code"), ("client_id", codexClientID), ("redirect_uri", codexRedirect),
            ("scope", "openid profile email offline_access"), ("code_challenge", challenge), ("code_challenge_method", "S256"),
            ("id_token_add_organizations", "true"), ("codex_cli_simplified_flow", "true"), ("state", state), ("originator", "codex_cli_rs"),
        ].map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url!
    }
    static func codexExchange(code: String, verifier: String) async throws {
        _ = try await codexToken(["grant_type": "authorization_code", "code": code, "redirect_uri": codexRedirect, "code_verifier": verifier], json: false)
    }
    /// Calls OpenAI's token endpoint and stores the returned access and (rotating) refresh tokens.
    private static func codexToken(_ parameters: [String: String], json: Bool) async throws -> String {
        let parameters = parameters.merging(["client_id": codexClientID]) { first, _ in first }
        var request = try request("https://auth.openai.com/oauth/token", headers: ["Content-Type": json ? "application/json" : "application/x-www-form-urlencoded"])
        request.httpMethod = "POST"
        if json { request.httpBody = try JSONSerialization.data(withJSONObject: parameters) }
        else {
            var form = URLComponents(); form.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.httpBody = Data((form.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        }
        let result = try await send(request)
        guard (200..<300).contains(result.status),
              let body = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any],
              let access = body["access_token"] as? String, !access.isEmpty else {
            throw Failure(message: (400..<500).contains(result.status) ? "Sign in to Codex again" : "Codex sign-in could not be renewed")
        }
        Store.set(access, for: .codexAccess)
        if let refresh = body["refresh_token"] as? String, !refresh.isEmpty { Store.set(refresh, for: .codexRefresh) }
        return access
    }

    // MARK: Grok (cursor.com session; the weekly pool shared by Grok, Grok Bot and Cursor)
    static func grok() async throws -> [Quota] {
        guard let token = Store.secret(.grokSession) else { throw Failure(message: "Not signed in") }
        var request = try request("https://cursor.com/api/dashboard/get-sand-usage-status", headers: [
            "Cookie": "WorkosCursorSessionToken=\(token)", "Origin": "https://cursor.com", "Content-Type": "application/json",
        ])
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        let result = try await send(request)
        try check(result.status, .grok, data: result.data)
        return try UsageParsing.grok(result.data)
    }

    // MARK: Refresh
    private static func group(_ provider: Provider, previous: UsageSnapshot, now: Double) async -> ProviderUsage {
        let empty = UsageSnapshot.phoneEmpty.groups.first { $0.id == provider.rawValue }!
        guard Store.isSignedIn(provider) else { var group = empty; group.message = "Not signed in"; return group }
        var last = previous.groups.first { $0.id == provider.rawValue } ?? empty
        do {
            let windows: [Quota]
            switch provider {
            case .claude: windows = try await claude()
            case .codex: windows = try await codex()
            case .grok: windows = try await grok()
            }
            return ProviderUsage(id: provider.rawValue, title: provider.rawValue.uppercased(), observedAt: now, stale: false, message: nil, windows: windows)
        } catch let failure as Failure { last.message = failure.message }
        catch is UsageParsing.Failure { last.message = "\(provider.title) usage was unreadable; showing last report" }
        catch { last.message = "\(provider.title) could not be reached; showing last report" }
        return last // keep the last good numbers; the clock badge appears once they are 15 minutes old
    }
    /// Fetches every signed-in provider and saves the result. Unless forced, reuses a snapshot under two minutes old
    /// so the app and the widget do not both query the providers.
    @discardableResult static func refresh(force: Bool) async -> UsageSnapshot {
        let previous = Store.snapshot, now = Date().timeIntervalSince1970
        #if targetEnvironment(simulator)
        if UserDefaults(suiteName: Store.group)?.bool(forKey: "sampleData") == true { return previous }
        #endif
        if !force, now - previous.generatedAt < 120 { return previous }
        async let claude = group(.claude, previous: previous, now: now)
        async let codex = group(.codex, previous: previous, now: now)
        async let grok = group(.grok, previous: previous, now: now)
        let snapshot = UsageSnapshot(version: 1, generatedAt: now, groups: await [claude, codex, grok])
        Store.save(snapshot)
        return snapshot
    }
}
