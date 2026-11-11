import Foundation
import Security

enum Provider: String, CaseIterable, Identifiable {
    case grok, claude, codex
    var id: String { rawValue }
    var title: String { self == .grok ? "Grok" : rawValue.capitalized }
    /// The account the sign-in belongs to, shown under the provider name.
    var account: String { self == .grok ? "Grok / Cursor account" : self == .claude ? "claude.ai account" : "ChatGPT account" }
}

/// Storage shared by the app and its widget: sign-ins in the Keychain, the last usage snapshot in the App Group.
enum Store {
    /// The App Group shared with the widget. Normally the one named in Info.plist; when the app has been
    /// re-signed by a sideloading tool (AltStore, Sideloadly) the group is renamed, so the names the
    /// signing profile actually grants are tried too. The first one iOS gives a container for wins.
    static let group: String = {
        let declared = Bundle.main.object(forInfoDictionaryKey: "TokenGaugeAppGroup") as? String ?? ""
        var granted: [String] = []
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"), let data = try? Data(contentsOf: url),
           let start = data.range(of: Data("<?xml".utf8)), let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
           let profile = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
           let groups = (profile["Entitlements"] as? [String: Any])?["com.apple.security.application-groups"] as? [String] {
            granted = groups.sorted { ($0.contains("TokenGauge") ? 0 : 1, $0) < ($1.contains("TokenGauge") ? 0 : 1, $1) }
        }
        let renamed = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        let candidates = ([declared] + granted + renamed).filter { !$0.isEmpty }
        return candidates.first { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil } ?? declared
    }()
    static var container: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    // MARK: Secrets (Keychain only; never written to files, logs or the snapshot)
    enum Secret: String, CaseIterable {
        case claudeSession = "claude.session", claudeOrganization = "claude.organization"
        case claudeAccess = "claude.access", claudeRefresh = "claude.refresh"
        case codexAccess = "codex.access", codexRefresh = "codex.refresh"
        case grokSession = "grok.session"
        static func all(for provider: Provider) -> [Secret] { allCases.filter { $0.rawValue.hasPrefix(provider.rawValue + ".") } }
    }
    private static func query(_ secret: Secret, shared: Bool) -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: "TokenGauge", kSecAttrAccount: secret.rawValue]
        // An App Group is also a Keychain access group on iOS, which lets the widget refresh by itself.
        if shared, !group.isEmpty { query[kSecAttrAccessGroup] = group }
        return query
    }
    static func secret(_ secret: Secret) -> String? {
        for shared in [true, false] {
            var query = query(secret, shared: shared)
            query[kSecReturnData] = true
            query[kSecMatchLimit] = kSecMatchLimitOne
            var item: CFTypeRef?
            if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data, !data.isEmpty {
                return String(decoding: data, as: UTF8.self)
            }
        }
        return nil
    }
    @discardableResult static func set(_ value: String?, for secret: Secret) -> Bool {
        for shared in [true, false] { SecItemDelete(query(secret, shared: shared) as CFDictionary) }
        guard let value, !value.isEmpty else { return true }
        for shared in [true, false] {
            var item = query(secret, shared: shared)
            item[kSecValueData] = Data(value.utf8)
            // After first unlock, so the widget can refresh while the phone is locked. Never synced to iCloud.
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            if SecItemAdd(item as CFDictionary, nil) == errSecSuccess { return true }
        }
        return false
    }
    static func isSignedIn(_ provider: Provider) -> Bool {
        switch provider {
        case .claude: return secret(.claudeAccess) != nil || secret(.claudeSession) != nil
        case .codex: return secret(.codexAccess) != nil
        case .grok: return secret(.grokSession) != nil
        }
    }
    static func signOut(_ provider: Provider) { Secret.all(for: provider).forEach { set(nil, for: $0) } }

    // MARK: Snapshot
    private static var snapshotURL: URL { container.appendingPathComponent("snapshot.json") }
    static var snapshot: UsageSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL), let value = try? JSONDecoder().decode(UsageSnapshot.self, from: data),
              value.version == 1 else { return .phoneEmpty }
        return value
    }
    static func save(_ snapshot: UsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try? data.write(to: snapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Runs `body` while holding a lock shared by the app and the widget, so only one of them
    /// renews a single-use refresh token at a time.
    static func locked<T>(_ name: String, _ body: () async throws -> T) async throws -> T {
        try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let descriptor = open(container.appendingPathComponent(name + ".lock").path, O_CREAT | O_RDWR, 0o600)
        defer { if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor) } }
        // Poll instead of blocking a thread; give up waiting after 20 seconds and proceed.
        var attempts = 0
        while descriptor >= 0, flock(descriptor, LOCK_EX | LOCK_NB) != 0, attempts < 80 {
            attempts += 1
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        return try await body()
    }
}

extension UsageSnapshot {
    /// All three providers, in the Mac widget's order, with nothing reported yet.
    static var phoneEmpty: UsageSnapshot {
        .init(version: 1, generatedAt: 0, groups: ["claude", "codex", "grok"].map { id in
            .init(id: id, title: id.uppercased(), observedAt: nil, stale: true, message: nil, windows: id == "grok"
                ? [.init(label: "7D", used: nil, reset: nil, duration: 604800)]
                : [.init(label: "5H", used: nil, reset: nil, duration: 18000), .init(label: "7D", used: nil, reset: nil, duration: 604800)])
        })
    }
}

#if targetEnvironment(simulator)
extension UsageSnapshot {
    /// Example data for checking layouts in the simulator.
    static var sample: UsageSnapshot {
        let now = Date().timeIntervalSince1970
        func group(_ id: String, _ windows: [Quota]) -> ProviderUsage {
            .init(id: id, title: id.uppercased(), observedAt: now, stale: false, message: nil, windows: windows)
        }
        return .init(version: 1, generatedAt: now, groups: [
            group("claude", [.init(label: "5H", used: 34, reset: now + 7200, duration: 18000), .init(label: "7D", used: 61, reset: now + 300_000, duration: 604800),
                             .init(label: "FABLE", used: 22, reset: now + 300_000, duration: 604800)]),
            group("codex", [.init(label: "5H", used: 12, reset: now + 12000, duration: 18000), .init(label: "7D", used: 47, reset: now + 200_000, duration: 604800)]),
            group("grok", [.init(label: "7D", used: 58, reset: now + 400_000, duration: 604800)]),
        ])
    }
}
#endif
