import SwiftUI
import WidgetKit

// Lock Screen widgets, one per provider. The Lock Screen row is four slots wide: a rectangular
// widget takes two and a circular one takes one, so two rectangles (or four circles) fill the row.
struct LockGaugeView: View {
    let provider: Provider
    let entry: GaugeEntry
    @Environment(\.widgetFamily) private var family
    private var group: ProviderUsage {
        entry.snapshot.groups.first { $0.id == provider.rawValue } ?? UsageSnapshot.phoneEmpty.groups.first { $0.id == provider.rawValue }!
    }
    private var weekly: Quota { group.windows.first { $0.duration >= 86400 } ?? group.windows[0] }
    private func percent(_ quota: Quota) -> String { quota.validUsage(at: entry.date).map { "\(Int($0.rounded()))%" } ?? "—" }
    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(group.title.capitalized + " " + group.windows.prefix(2).map { "\($0.label) \(percent($0))" }.joined(separator: " · "))
            case .accessoryCircular:
                // One slot: the weekly window, with the provider's logo under the value.
                Fit(width: 48, height: 48, padding: 2) {
                    ZStack {
                        QuotaTrack(quota: weekly, date: entry.date, diameter: 48, thickness: 4.5, colors: [.white, .white], accented: true)
                        Text(weekly.label).font(.system(size: 8, weight: .semibold)).offset(y: -21.75)
                        Text(percent(weekly)).font(.system(size: 12, weight: .semibold)).monospacedDigit().offset(y: -2)
                        ProviderMark(provider: group.id).fill(.primary).frame(width: 9, height: 9).offset(y: 12)
                    }
                }
            default:
                // Two slots: logo, both gauges and their reset times.
                Fit(width: 140, height: 68, padding: 0) {
                    ProviderPanel(group: group, date: entry.date, size: .small, accented: true, gap: 8, logoGap: 7, resetGap: 3, resetBeside: true)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .containerBackground(for: .widget) { Color.clear }
    }
}

private func lockConfiguration(_ provider: Provider) -> some WidgetConfiguration {
    StaticConfiguration(kind: "TokenGaugeLock-" + provider.rawValue, provider: GaugeTimeline()) { entry in
        LockGaugeView(provider: provider, entry: entry)
    }
    // Plain strings: WidgetKit asserts on a localized key that carries interpolated arguments.
    .configurationDisplayName(Text(verbatim: provider.title + " usage"))
    .description(Text(verbatim: "Lock Screen gauge for " + provider.title + ". Wide shows every window and reset time; round shows the weekly one."))
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
}
struct ClaudeLockWidget: Widget { var body: some WidgetConfiguration { lockConfiguration(.claude) } }
struct CodexLockWidget: Widget { var body: some WidgetConfiguration { lockConfiguration(.codex) } }
struct GrokLockWidget: Widget { var body: some WidgetConfiguration { lockConfiguration(.grok) } }

@main
struct TokenGaugeWidgets: WidgetBundle {
    var body: some Widget {
        TokenGaugeWidget()
        ClaudeLockWidget()
        CodexLockWidget()
        GrokLockWidget()
    }
}
