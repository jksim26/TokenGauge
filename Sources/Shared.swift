import SwiftUI
import Foundation
import WidgetKit
#if canImport(AppKit)
import AppKit
#endif

struct Quota: Codable, Identifiable {
    var label: String
    var used: Double?
    var reset: Double?
    var duration: Double
    var id: String { label }
    func validUsage(at date: Date) -> Double? {
        if let reset, reset <= date.timeIntervalSince1970 { return nil }
        return used
    }
}
struct ProviderUsage: Codable, Identifiable {
    var id: String
    var title: String
    var observedAt: Double?
    var stale: Bool
    var message: String?
    var windows: [Quota]
    func isStale(at date: Date) -> Bool {
        guard let observedAt else { return true }
        return stale || date.timeIntervalSince1970 - observedAt >= 900
    }
    var accent: Color { id == "claude" ? Color(red: 217.0 / 255, green: 119.0 / 255, blue: 87.0 / 255) : id == "grok" ? .primary : Color(red: 0.48, green: 0.72, blue: 0.96) }
}
struct UsageSnapshot: Codable {
    var version: Int
    var generatedAt: Double
    var groups: [ProviderUsage]
    static var empty: UsageSnapshot {
        .init(version: 1, generatedAt: Date().timeIntervalSince1970, groups: ["claude", "codex"].map {
            .init(id: $0, title: $0.uppercased(), observedAt: nil, stale: true, message: "Waiting for usage", windows: [
                .init(label: "5H", used: nil, reset: nil, duration: 18000),
                .init(label: "7D", used: nil, reset: nil, duration: 604800)
            ])
        })
    }
}
enum Bridge {
    static func fetch(refresh: Bool = false) async throws -> UsageSnapshot {
        let url = URL(string: "http://127.0.0.1:43871/" + (refresh ? "refresh" : "snapshot"))!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: refresh ? 30 : 5)
        if refresh { request.httpMethod = "POST" }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let model = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        guard model.version == 1 else { throw URLError(.cannotParseResponse) }
        UserDefaults.standard.set(data, forKey: "lastSnapshot")
        return model
    }
    static var cached: UsageSnapshot {
        guard let data = UserDefaults.standard.data(forKey: "lastSnapshot"), let model = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else { return .empty }
        return model
    }
}

enum GaugeSize {
    case small, medium, large
    var diameter: CGFloat { self == .small ? 48 : self == .large ? 88 : 64 }
    var lineWidth: CGFloat { self == .small ? 4.5 : self == .large ? 8 : 6 }
    var valueFont: CGFloat { self == .small ? 11 : self == .large ? 22 : 16 }
}

enum ResetTime {
    static func string(epoch: Double?, weekly: Bool, timeZone: TimeZone = .current) -> String {
        guard let epoch, epoch.isFinite else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.dateFormat = weekly ? "EEE h:mma" : "h:mma"
        // Provider responses can jitter a fraction of a second around the
        // reset boundary; normalize to seconds before formatting the minute.
        return formatter.string(from: Date(timeIntervalSince1970: epoch.rounded()))
    }
}

private func gaugeColor(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
}
struct QuotaTrack: View {
    let quota: Quota
    let date: Date
    let diameter: CGFloat
    let thickness: CGFloat
    let colors: [Color]
    var accented = false
    private func ring(value: Double, diameter: CGFloat, width: CGFloat, color: Color) -> some View {
        let progress = min(1, max(0, CGFloat(value) / 100))
        let radius = (diameter - width) / 2
        return ZStack {
            Circle().inset(by: width / 2).trim(from: 0, to: 300.0 / 360).stroke(.primary.opacity(0.14), style: StrokeStyle(lineWidth: width, lineCap: .round)).rotationEffect(.degrees(-60))
            if value > 0 {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let end = (-60 + Double(progress) * 300) * Double.pi / 180
                    func point(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a)) }
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: .degrees(-60), endAngle: .radians(end), clockwise: false)
                    let shape = arc.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
                    let start = accented ? Color.white.opacity(0.65) : colors[0]
                    let finish = accented ? Color.white : colors[1]
                    let extent = max(0.001, Double(progress) * 300 / 360)
                    context.fill(shape, with: .conicGradient(Gradient(stops: [
                        .init(color: start, location: 0),
                        .init(color: finish, location: extent),
                        .init(color: finish, location: 1)
                    ]), center: center, angle: .degrees(-60)))

                }

            }
        }.frame(width: diameter, height: diameter)
    }
    var body: some View {
        ring(value: quota.validUsage(at: date) ?? 0, diameter: diameter, width: thickness, color: colors[0])
    }
}
struct GaugeCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let quota: Quota
    var secondary: Quota?
    let provider: String
    let date: Date
    var size: GaugeSize = .medium
    var accented = false
    var showReset = true
    var resetGap: CGFloat?
    var resetFont: CGFloat?
    private var innerWidth: CGFloat { size == .small ? 1.6 : size == .large ? 3 : 2.2 }
    private var colors: [Color] {
        let weekly = quota.duration >= 86400
        if provider == "claude" {
            return weekly ? [gaugeColor(0xD97757), gaugeColor(0xE38D70)] : [gaugeColor(0xE28B6D), gaugeColor(0xEBA085)]
        }
        if provider == "grok" {
            // Grok's monochrome brand: white on dark surfaces, near-black on light ones.
            return colorScheme == .dark ? [gaugeColor(0xBDBDBD), gaugeColor(0xFFFFFF)] : [gaugeColor(0x4A4A4A), gaugeColor(0x111111)]
        }
        return weekly ? [gaugeColor(0x3285F5), gaugeColor(0x5098FA)] : [gaugeColor(0x5BA4FA), gaugeColor(0x7BB9FF)]
    }
    private var innerColors: [Color] { [gaugeColor(0xE4B55D), gaugeColor(0xF0CA80)] }
    private func value(_ q: Quota) -> String { q.validUsage(at: date).map { "\(Int($0.rounded()))%" } ?? "—" }
    private func reset(_ q: Quota) -> String { ResetTime.string(epoch: q.reset, weekly: q.duration >= 86400) }
    private var accessibilitySummary: String {
        var result = "\(provider.capitalized), \(quota.label), \(value(quota)) used, resets \(reset(quota))"
        if let secondary { result += ", Fable weekly, \(value(secondary)) used, resets \(reset(secondary))" }
        if let end = quota.reset, quota.duration > 0 { result += ", elapsed window \(Int(min(1, max(0, 1 - (end - date.timeIntervalSince1970) / quota.duration)) * 100)) percent" }
        return result
    }
    var body: some View {
        VStack(spacing: resetGap ?? (size == .small ? 7 : size == .large ? 15 : 13)) {
            ZStack {
                QuotaTrack(quota: quota, date: date, diameter: size.diameter, thickness: size.lineWidth, colors: colors, accented: accented)
                if let secondary {
                    QuotaTrack(quota: secondary, date: date, diameter: size.diameter - 2 * (size.lineWidth + 0.5), thickness: innerWidth, colors: innerColors, accented: accented)
                }
                if let end = quota.reset, quota.duration > 0, quota.validUsage(at: date) != nil {
                    let fraction = min(1, max(0, 1 - (end - date.timeIntervalSince1970) / quota.duration))
                    let length = size.lineWidth + (secondary == nil ? 0 : 0.5 + innerWidth)
                    Capsule().fill(accented ? Color.white : gaugeColor(0xFF4558))
                        // Tinted and Lock Screen rendering is one colour: lengthen and outline the marker so it shows on the filled arc.
                        .frame(width: size == .small ? 1.6 : 2, height: length + (accented ? 3 : 0))
                        .overlay { if accented { Capsule().stroke(.black, lineWidth: 0.8) } }
                        .shadow(color: .black.opacity(0.55), radius: 0.6)
                        .offset(y: -(size.diameter - length) / 2)
                        .rotationEffect(.degrees(30 + fraction * 300))
                }
                Text(quota.label).font(.system(size: size == .small ? 8 : size == .large ? 12 : 10, weight: .semibold))
                    .offset(y: -size.diameter / 2 + size.lineWidth / 2)
                if secondary != nil {
                    Text("F").font(.system(size: size == .small ? 5.5 : size == .large ? 8 : 7, weight: .medium))
                        .offset(y: -size.diameter / 2 + size.lineWidth / 2 + (size == .small ? 7 : size == .large ? 12 : 10))
                }
                Text(value(quota)).font(.system(size: size.valueFont, weight: .medium)).monospacedDigit()
                if let secondary {
                    Text(value(secondary)).font(.system(size: size == .small ? 7 : size == .large ? 11 : 9, weight: .regular)).monospacedDigit()
                        .foregroundStyle(accented ? Color.primary : colorScheme == .light ? gaugeColor(0x704508) : gaugeColor(0xF0CA80))
                        .offset(y: size == .small ? 11 : size == .large ? 20 : 14)
                }
            }.frame(width: size.diameter, height: size.diameter)
            if showReset {
                Text(quota.validUsage(at: date) == nil ? "—" : reset(quota))
                    .font(.system(size: resetFont ?? (size == .small ? 8.5 : size == .large ? 12 : 10.5), weight: .medium))
                    .foregroundStyle(.primary.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.85)
            }
        }.frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .help(accessibilitySummary)
    }
}

struct ProviderPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    let group: ProviderUsage
    let date: Date
    var size: GaugeSize = .medium
    var accented = false
    var showReset = true
    var logoBeside = false
    var gap: CGFloat?        // between the two gauges
    var logoGap: CGFloat?    // between the logo and the gauges
    var resetGap: CGFloat?   // between a gauge and its reset time
    var logoSize: CGFloat?
    var resetFont: CGFloat?
    var resetBeside = false  // single-gauge providers: reset time fills the second gauge's place
    private var primary: Quota { group.windows.first ?? UsageSnapshot.empty.groups[0].windows[0] }
    private var weekly: Quota { group.windows.dropFirst().first ?? UsageSnapshot.empty.groups[0].windows[1] }
    private var fable: Quota? {
        group.id == "claude" ? group.windows.first(where: { $0.label.uppercased() == "FABLE" }) : nil
    }
    private var logo: some View {
        ProviderMark(provider: group.id)
            .fill(group.id == "claude" && !accented ? group.accent : colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
            .frame(width: logoSize ?? (size == .small ? 16 : size == .large ? 22.4 : 19.2), height: logoSize ?? (size == .small ? 16 : size == .large ? 22.4 : 19.2))
            .accessibilityLabel(group.title)
            .overlay(alignment: .topTrailing) {
                if group.isStale(at: date) {
                    Image(systemName: "clock.fill").font(.system(size: 6)).offset(x: 5, y: -3).foregroundStyle(.secondary)
                }
            }
    }
    private var besideActive: Bool { resetBeside && group.windows.count == 1 }
    private var cells: some View {
        HStack(alignment: resetBeside ? .center : .top, spacing: gap ?? (size == .small ? 6 : size == .large ? 22 : 4)) {
            GaugeCell(quota: primary, provider: group.id, date: date, size: size, accented: accented, showReset: showReset && !besideActive, resetGap: resetGap, resetFont: resetFont)
            if group.windows.count != 1 {
                GaugeCell(quota: weekly, secondary: fable, provider: group.id, date: date, size: size, accented: accented, showReset: showReset, resetGap: resetGap, resetFont: resetFont)
            } else if besideActive {
                let parts = (primary.validUsage(at: date) == nil ? "—" : ResetTime.string(epoch: primary.reset, weekly: primary.duration >= 86400)).split(separator: " ", maxSplits: 1)
                VStack(spacing: size == .large ? 3 : 1) {
                    if parts.count > 1 { Text(parts[0].uppercased()).font(.system(size: size == .small ? 8.5 : size == .large ? 12 : 10, weight: .semibold)).foregroundStyle(.secondary) }
                    Text(parts.last.map(String.init) ?? "—").font(.system(size: size == .small ? 10.5 : size == .large ? 17 : 13, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.primary.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.8)
                }.frame(width: size.diameter).accessibilityHidden(true)
            }
        }
    }
    var body: some View {
        Group {
            if size == .small || logoBeside {
                HStack(spacing: logoGap ?? (size == .small ? 5 : 10)) { logo; cells }
            } else {
                VStack(spacing: logoGap ?? (size == .large ? 8 : 5)) { logo; cells }
            }
        }.frame(maxWidth: .infinity)
    }
}

private struct Hairline: View {
    var vertical = false
    var body: some View {
        Rectangle().fill(.primary.opacity(0.14))
            .frame(width: vertical ? 0.5 : nil, height: vertical ? nil : 0.5)
            .accessibilityHidden(true)
    }
}

/// Lays its content out at natural size and scales it to fill the space, so the same design fits every widget size.
struct Fit<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    var padding: CGFloat = 10
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geo in
            let scale = min((geo.size.width - 2 * padding) / width, (geo.size.height - 2 * padding) / height)
            content().fixedSize().scaleEffect(max(0.1, scale))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// Three providers stacked as rows: Grok first, each row a logo and its gauges.
private struct ProviderRows: View {
    let snapshot: UsageSnapshot
    let date: Date
    let size: GaugeSize
    let accented: Bool
    var body: some View {
        let groups = snapshot.groups.filter { $0.id == "grok" } + snapshot.groups.filter { $0.id != "grok" }
        let large = size == .large
        VStack(spacing: large ? 15 : 7) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if index > 0 { Hairline() }
                ProviderPanel(group: group, date: date, size: size, accented: accented, showReset: large, logoBeside: true,
                              gap: large ? 34 : 14, logoGap: large ? 20 : 9, resetGap: 6, resetBeside: true)
            }
        }
    }
}

struct SmallGaugeDashboard: View {
    let snapshot: UsageSnapshot
    var date = Date()
    var offline = false
    var accented = false
    var margin: CGFloat = 16 // the widget's content margins are disabled; the app passes 0
    var body: some View {
        if snapshot.groups.count > 2 { threeRows } else { twoRows }
    }
    // Three providers: one row each, Grok first. Only Grok has room for its reset time; the rest are in the tooltip.
    private var threeRows: some View {
        Fit(width: 137, height: 172) { ProviderRows(snapshot: snapshot, date: date, size: .small, accented: accented) }
        .overlay(alignment: .topTrailing) {
            if offline { Image(systemName: "wifi.slash").font(.system(size: 7)).foregroundStyle(.secondary).padding(8) }
        }
    }
    private var twoRows: some View {
        VStack(spacing: 8) {
            ForEach(snapshot.groups) { group in ProviderPanel(group: group, date: date, size: .small, accented: accented) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { Rectangle().fill(.primary.opacity(0.14)).frame(height: 0.5).padding(.horizontal, 5).accessibilityHidden(true) }
        .padding(margin)
        .overlay(alignment: .topTrailing) {
            if offline { Image(systemName: "wifi.slash").font(.system(size: 7)).foregroundStyle(.secondary) }
        }
    }
}

struct GaugeDashboard: View {
    let snapshot: UsageSnapshot
    var date = Date()
    var large = false
    var offline = false
    var accented = false
    var margin: CGFloat = 16 // the widget's content margins are disabled; the app passes 0
    var body: some View {
        if snapshot.groups.count > 2 { three } else { two }
    }
    private func panel(_ group: ProviderUsage) -> some View {
        ProviderPanel(group: group, date: date, accented: accented)
    }
    // Three providers. Medium: Grok on the left, Claude over Codex on the right. Large: one row each, Grok first.
    private var three: some View {
        let grok = snapshot.groups.filter { $0.id == "grok" }
        let others = snapshot.groups.filter { $0.id != "grok" }
        return Group {
            if large {
                Fit(width: 256, height: 368) { ProviderRows(snapshot: snapshot, date: date, size: .large, accented: accented) }
            } else {
                // One row. Five gauges across make this width-bound, so the logos and reset times are enlarged to use the height.
                Fit(width: 388, height: 122, padding: 8) {
                    HStack(alignment: .center, spacing: 11) {
                        ForEach(Array((grok + others).enumerated()), id: \.element.id) { index, group in
                            if index > 0 { Hairline(vertical: true).frame(height: 104) }
                            ProviderPanel(group: group, date: date, accented: accented, gap: 8, logoGap: 8, resetGap: 9, logoSize: 24, resetFont: 11)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if offline { Image(systemName: "wifi.slash").font(.system(size: 9)).foregroundStyle(.secondary).padding(10) }
        }
    }
    private var two: some View {
        Group {
            if large {
                VStack(spacing: 16) {
                    ForEach(snapshot.groups) { group in ProviderPanel(group: group, date: date, size: .large, accented: accented) }
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    ForEach(snapshot.groups) { group in ProviderPanel(group: group, date: date, accented: accented) }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if large {
                Rectangle().fill(.primary.opacity(0.14)).frame(height: 0.5).padding(.horizontal, 8).accessibilityHidden(true)
            } else {
                Rectangle().fill(.primary.opacity(0.14)).frame(width: 0.5, height: 96).accessibilityHidden(true)
            }
        }
        .padding(margin)
        .overlay(alignment: .topTrailing) {
            if offline { Image(systemName: "wifi.slash").font(.system(size: 9)).foregroundStyle(.secondary) }
        }
    }
}

struct GaugeGlassSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}
