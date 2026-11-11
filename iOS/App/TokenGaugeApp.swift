import AuthenticationServices
import BackgroundTasks
import SwiftUI
import WidgetKit

let surface = Color(red: 0.11, green: 0.11, blue: 0.118)

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot = Store.snapshot
    @Published var signedIn = Dictionary(uniqueKeysWithValues: Provider.allCases.map { ($0, Store.isSignedIn($0)) })
    @Published var busy = false
    @Published var notice: String?

    init() {
        #if targetEnvironment(simulator)
        // Simulator only: `-sampleData` shows example gauges without any sign-in, for checking layouts.
        let sample = CommandLine.arguments.contains("-sampleData")
        UserDefaults(suiteName: Store.group)?.set(sample, forKey: "sampleData")
        if sample { Store.save(.sample); snapshot = Store.snapshot }
        #endif
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        snapshot = await UsageService.refresh(force: true)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func signedIn(_ provider: Provider) async {
        signedIn[provider] = Store.isSignedIn(provider)
        notice = nil
        await refresh()
    }
    func signOut(_ provider: Provider) async {
        Store.signOut(provider)
        if provider != .codex { await LoopbackSignIn.clearWebSession(domain: provider == .claude ? "claude.ai" : "cursor.com") }
        await signedIn(provider)
    }
    /// Claude through Safari's sign-in. Returns false when that route fails, so the caller can fall back to the in-app page.
    func signInClaude() async -> Bool {
        do { try await LoopbackSignIn.claude(); await signedIn(.claude); return true }
        catch is CancellationError { return true }
        catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin { return true }
        catch { return false }
    }
    func signInCodex() async {
        do { try await LoopbackSignIn.codex(); await signedIn(.codex) }
        catch is CancellationError {}
        catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {}
        catch { notice = (error as? UsageService.Failure)?.message ?? "ChatGPT sign-in did not finish. Try again." }
    }
}
@main
struct TokenGaugeApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    // Taken from Info.plist, not the bundle ID: a re-signed copy has a different bundle ID, and iOS
    // rejects a background task whose name is not in the permitted list.
    static let refreshTask = (Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String])?.first
        ?? (Bundle.main.bundleIdentifier ?? "TokenGauge") + ".refresh"
    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTask)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model).preferredColorScheme(.dark)
        }
        .onChange(of: phase) { _, phase in if phase == .background { Self.scheduleRefresh() } }
        // iOS runs this now and then while the app is closed, to keep the widget current.
        .backgroundTask(.appRefresh(Self.refreshTask)) {
            Self.scheduleRefresh()
            await UsageService.refresh(force: true)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var phase
    @State private var signingIn: Provider?

    private var updated: String {
        guard model.snapshot.generatedAt > 0 else { return "Sign in below to start" }
        return "Updated " + ResetTime.string(epoch: model.snapshot.generatedAt, weekly: false)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        GaugeDashboard(snapshot: model.snapshot, date: context.date)
                            .frame(maxWidth: .infinity).frame(height: 170)
                            .background(surface, in: RoundedRectangle(cornerRadius: 24))
                    }
                    Text(updated).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    if let notice = model.notice { Text(notice).font(.footnote).foregroundStyle(.orange) }
                    VStack(spacing: 0) {
                        ForEach(Provider.allCases) { provider in
                            if provider != Provider.allCases.first { Divider().padding(.leading, 52) }
                            row(provider)
                        }
                    }.background(surface, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Add the widget", systemImage: "square.grid.2x2").font(.subheadline.weight(.semibold))
                        Text("Touch and hold the Home Screen, tap Edit, then Add Widget, and search for Token Gauge. iOS decides how often widgets update; opening this app always fetches the latest usage.")
                        Label("Sign-ins stay on this iPhone", systemImage: "lock").font(.subheadline.weight(.semibold)).padding(.top, 6)
                        Text("Each sign-in is kept in the iPhone's Keychain and sent only to the service it belongs to. Only usage percentages and reset times are read.")
                    }.font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(Color.black)
            .navigationTitle("Token Gauge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.refresh() } } label: {
                        if model.busy { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }.disabled(model.busy).accessibilityLabel("Refresh")
                }
            }
            .refreshable { await model.refresh() }
        }
        .sheet(item: $signingIn) { provider in SignInSheet(provider: provider) { signingIn = nil; Task { await model.signedIn(provider) } } }
        .task(id: phase) {
            // Refresh when opened, then every three minutes while the app stays on screen.
            guard phase == .active else { return }
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(nanoseconds: 180_000_000_000)
            }
        }
    }
    private func row(_ provider: Provider) -> some View {
        let group = model.snapshot.groups.first { $0.id == provider.rawValue }
        let isSignedIn = model.signedIn[provider] == true
        return HStack(spacing: 14) {
            ProviderMark(provider: provider.rawValue)
                .fill(provider == .claude ? Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255) : Color.white.opacity(0.9))
                .frame(width: 24, height: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.title).font(.body.weight(.medium))
                Text(isSignedIn ? (group?.message ?? "Signed in") : provider.account)
                    .font(.footnote).foregroundStyle(isSignedIn && group?.message != nil ? Color.orange : Color.secondary)
            }
            Spacer()
            if isSignedIn {
                Button("Sign out", role: .destructive) { Task { await model.signOut(provider) } }.font(.subheadline)
            } else {
                Button("Sign in") {
                    switch provider {
                    case .codex: Task { await model.signInCodex() }
                    case .claude: Task { if await !model.signInClaude() { signingIn = .claude } }
                    case .grok: signingIn = provider
                    }
                }.buttonStyle(.borderedProminent).font(.subheadline)
            }
        }.padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/// Claude and Grok sign in on their own web pages; the session cookie is stored when it appears.
struct SignInSheet: View {
    let provider: Provider
    let done: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if provider == .claude {
                    CookieSignIn(url: URL(string: "https://claude.ai/login")!, cookieName: "sessionKey", domain: "claude.ai") { cookies in
                        // Keep the session plus the security cookies Claude's web checks expect, as the Mac helper does.
                        let header = ["sessionKey", "lastActiveOrg", "cf_clearance", "__cf_bm", "anthropic-device-id"]
                            .compactMap { name in cookies[name].map { "\(name)=\($0)" } }.joined(separator: "; ")
                        Store.set(cookies["lastActiveOrg"], for: .claudeOrganization)
                        Store.set(header, for: .claudeSession)
                        done()
                    }
                } else {
                    CookieSignIn(url: URL(string: "https://cursor.com/dashboard")!, cookieName: "WorkosCursorSessionToken", domain: "cursor.com") { cookies in
                        Store.set(cookies["WorkosCursorSessionToken"], for: .grokSession)
                        done()
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(provider == .claude ? "Sign in to Claude" : "Sign in to Grok / Cursor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
