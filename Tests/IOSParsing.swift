// Checks the iPhone app's response parsing on the Mac:
//   xcrun swiftc -parse-as-library Sources/Shared.swift Sources/ProviderMark.swift iOS/Shared/Parsing.swift Tests/IOSParsing.swift -o build/ios-parsing && build/ios-parsing
import Foundation

@main
struct IOSParsingTests {
    static func check(_ condition: @autoclosure () throws -> Bool, _ name: String, line: Int = #line) {
        if (try? condition()) != true { print("FAIL line \(line): \(name)"); exit(1) }
    }
    static func main() throws {
        // Codex: the live response shape (values from a real response, 2026-11-11).
        let codex = try UsageParsing.codex(Data(#"{"plan_type":"plus","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":1,"limit_window_seconds":18000,"reset_after_seconds":14570,"reset_at":1794354718},"secondary_window":{"used_percent":10,"limit_window_seconds":604800,"reset_at":1794903227}}}"#.utf8))
        check(codex.map(\.label) == ["5H", "7D"], "codex labels")
        check(codex[0].used == 1 && codex[1].used == 10, "codex percentages, including a real 1")
        check(codex[0].reset == 1794354718 && codex[1].duration == 604800, "codex reset and duration")
        check((try? UsageParsing.codex(Data(#"{"rate_limit":{"primary_window":{"used_percent":true}}}"#.utf8))) == nil, "booleans are not percentages")
        check((try? UsageParsing.codex(Data("{}".utf8))) == nil, "missing rate_limit is unreadable")

        // Claude: explicit model-scoped percent becomes Fable; the all-models row and bad values are ignored.
        let claude = try UsageParsing.claude(Data(#"{"five_hour":{"utilization":6,"resets_at":"2030-01-01T00:00:00Z"},"seven_day":{"utilization":96.5,"resets_at":"2030-01-07T00:00:00.123Z"},"limits":[{"kind":"weekly_scoped","percent":10,"resets_at":"2030-01-07T00:00:00Z","scope":{"model":{"display_name":"Fable"}}},{"kind":"weekly_scoped","percent":"25","resets_at":"2030-01-07T00:00:00Z","scope":{"model":{"display_name":"Invalid"}}},{"kind":"weekly_scoped","percent":96,"resets_at":"2030-01-07T00:00:00Z","scope":{"model":{"display_name":"All models"}}}]}"#.utf8))
        check(claude.map(\.label) == ["5H", "7D", "FABLE"], "claude labels")
        check(claude[0].used == 6 && claude[1].used == 96.5 && claude[2].used == 10, "claude percentages")
        check(claude[0].reset == 1893456000, "claude ISO reset")
        check(claude[1].reset.map { abs($0 - 1893974400.123) < 0.01 } == true, "claude fractional ISO reset")
        check((try? UsageParsing.claude(Data(#"{"five_hour":null,"seven_day":null}"#.utf8))) == nil, "no windows is unreadable")
        check(try UsageParsing.claudeOrganization(Data(#"[{"uuid":"11111111-1111-1111-1111-111111111111","capabilities":["api"]},{"uuid":"22222222-2222-2222-2222-222222222222","capabilities":["chat"]}]"#.utf8)) == "22222222-2222-2222-2222-222222222222", "chat organization preferred")
        check((try? UsageParsing.claudeOrganization(Data(#"[{"uuid":"../evil"}]"#.utf8))) == nil, "organization id must be a UUID")

        // Grok: weekly pool percent and ISO reset.
        let grok = try UsageParsing.grok(Data(#"{"usagePercent":9.187,"nextResetTimestampUtc":"2026-11-14T11:54:15.715Z","hasNonZeroIncludedLimit":true}"#.utf8))
        check(grok.count == 1 && grok[0].label == "7D" && grok[0].duration == 604800, "grok window")
        check(grok[0].used.map { abs($0 - 9.187) < 0.001 } == true, "grok percent")
        check(grok[0].reset.map { abs($0 - 1794657255.715) < 0.01 } == true, "grok reset")
        check(try UsageParsing.grok(Data(#"{"usagePercent":0}"#.utf8))[0].used == 0, "grok zero is real")
        check((try? UsageParsing.grok(Data(#"{"nextResetTimestampUtc":"x"}"#.utf8))) == nil, "grok without percent is unreadable")

        // Token expiry and the localhost OAuth redirect.
        let payload = Data(#"{"exp":2000000000}"#.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        check(UsageParsing.jwtExpiry("a.\(payload).c") == 2000000000, "jwt exp")
        check(UsageParsing.jwtExpiry("not-a-jwt") == nil, "bad jwt")
        check(try UsageParsing.oauthCallbackCode(request: "GET /auth/callback?code=abc&state=s1 HTTP/1.1\r\nHost: localhost:1455\r\n\r\n", state: "s1") == "abc", "callback code")
        check(try UsageParsing.oauthCallbackCode(request: "GET /favicon.ico HTTP/1.1\r\n\r\n", state: "s1") == nil, "other paths ignored")
        check((try? UsageParsing.oauthCallbackCode(request: "GET /auth/callback?code=abc&state=wrong HTTP/1.1\r\n\r\n", state: "s1")) == nil, "state mismatch rejected")
        print("iOS parsing: all checks passed")
    }
}
