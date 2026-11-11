import Foundation

// Pure parsing of each provider's usage response. Foundation only, so it is also tested on the Mac.
enum UsageParsing {
    enum Failure: Error { case unreadable }

    static func date(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { let v = number.doubleValue; return v > 100_000_000_000 ? v / 1000 : v }
        guard let text = value as? String, !text.isEmpty else { return nil }
        if let v = Double(text) { return v > 100_000_000_000 ? v / 1000 : v }
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return (fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text))?.timeIntervalSince1970
    }
    private static func number(_ value: Any?) -> Double? {
        // JSON booleans are also NSNumbers; reject them without rejecting a real 0 or 1.
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let v = number.doubleValue
        return v.isFinite ? v : nil
    }
    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
    static func label(seconds: Double) -> String {
        if seconds == 18000 { return "5H" }
        if seconds == 604800 { return "7D" }
        return seconds.truncatingRemainder(dividingBy: 3600) == 0 ? "\(Int(seconds / 3600))H" : "\(Int((seconds / 60).rounded()))M"
    }
    private static func object(_ data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.unreadable }
        return json
    }

    /// claude.ai `/api/organizations`: prefer the organization that can chat (the subscription one).
    static func claudeOrganization(_ data: Data) throws -> String {
        guard let orgs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw Failure.unreadable }
        let chat = orgs.first { ($0["capabilities"] as? [String])?.contains("chat") == true }
        guard let uuid = (chat ?? orgs.first)?["uuid"] as? String,
              uuid.range(of: "^[a-fA-F0-9-]{36}$", options: .regularExpression) != nil else { throw Failure.unreadable }
        return uuid
    }

    /// claude.ai `/api/organizations/{org}/usage`: 5-hour and 7-day windows plus model-scoped weekly limits (Fable).
    static func claude(_ data: Data) throws -> [Quota] {
        let json = try object(data)
        func window(_ key: String, _ label: String, _ duration: Double) -> Quota {
            let raw = json[key] as? [String: Any]
            return Quota(label: label, used: number(raw?["utilization"]).map(clamp), reset: date(raw?["resets_at"]), duration: duration)
        }
        var result = [window("five_hour", "5H", 18000), window("seven_day", "7D", 604800)]
        var seen = Set<String>()
        for item in json["limits"] as? [[String: Any]] ?? [] {
            guard item["kind"] as? String == "weekly_scoped",
                  let name = ((item["scope"] as? [String: Any])?["model"] as? [String: Any])?["display_name"] as? String,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty,
                  name.range(of: "all models", options: .caseInsensitive) == nil,
                  let percent = number(item["percent"]), let reset = date(item["resets_at"]) else { continue }
            let label = String(name.trimmingCharacters(in: .whitespaces).prefix(10)).uppercased()
            guard seen.insert(label).inserted else { continue }
            result.append(Quota(label: label, used: clamp(percent), reset: reset, duration: 604800))
        }
        guard result.contains(where: { $0.used != nil }) else { throw Failure.unreadable }
        return result
    }

    /// chatgpt.com `/backend-api/wham/usage`: primary (5-hour) and secondary (weekly) windows.
    static func codex(_ data: Data) throws -> [Quota] {
        guard let limit = try object(data)["rate_limit"] as? [String: Any] else { throw Failure.unreadable }
        func window(_ key: String, _ fallback: Double) -> Quota {
            let raw = limit[key] as? [String: Any]
            let seconds = number(raw?["limit_window_seconds"]).flatMap { $0 > 0 ? $0 : nil } ?? fallback
            return Quota(label: label(seconds: seconds), used: number(raw?["used_percent"]).map(clamp), reset: date(raw?["reset_at"]), duration: seconds)
        }
        let result = [window("primary_window", 18000), window("secondary_window", 604800)]
        guard result.contains(where: { $0.used != nil }) else { throw Failure.unreadable }
        return result
    }

    /// cursor.com `/api/dashboard/get-sand-usage-status`: the weekly pool shared by Grok, Grok Bot and Cursor.
    static func grok(_ data: Data) throws -> [Quota] {
        let json = try object(data)
        guard let used = number(json["usagePercent"]), used >= 0 else { throw Failure.unreadable }
        return [Quota(label: "7D", used: clamp(used), reset: date(json["nextResetTimestampUtc"]), duration: 604800)]
    }

    /// Expiry (`exp`) of a JWT access token, without verifying it; used only to decide when to renew.
    static func jwtExpiry(_ token: String) -> Double? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return number(json["exp"])
    }

    /// The authorization code from the raw HTTP request a browser sends to the localhost OAuth redirect.
    /// Returns nil for unrelated requests (such as /favicon.ico); throws when the state does not match.
    static func oauthCallbackCode(request: String, state: String, path: String = "/auth/callback") throws -> String? {
        let parts = request.split(separator: "\r\n", maxSplits: 1).first?.split(separator: " ") ?? []
        guard parts.count >= 2, parts[0] == "GET", let url = URLComponents(string: "http://localhost\(parts[1])"),
              url.path == path else { return nil }
        let items = Dictionary((url.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        guard items["state"] == state, let code = items["code"], !code.isEmpty else { throw Failure.unreadable }
        return code
    }
}
