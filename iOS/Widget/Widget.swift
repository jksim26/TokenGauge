import SwiftUI
import WidgetKit

struct GaugeEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct GaugeTimeline: TimelineProvider {
    func placeholder(in context: Context) -> GaugeEntry { .init(date: Date(), snapshot: .phoneEmpty) }
    func getSnapshot(in context: Context, completion: @escaping (GaugeEntry) -> Void) {
        completion(.init(date: Date(), snapshot: Store.snapshot))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GaugeEntry>) -> Void) {
        Task {
            // The widget fetches by itself with the sign-ins in the shared Keychain, so it stays
            // current without the app being opened. iOS decides how often this runs.
            let model = await UsageService.refresh(force: false)
            let now = Date(), next = now.addingTimeInterval(15 * 60)
            // Extra entries keep the pace markers, expired windows and stale badges right between fetches.
            var dates = [now] + stride(from: 5.0, to: 30, by: 5).map { now.addingTimeInterval($0 * 60) }
            for group in model.groups {
                if let observed = group.observedAt { dates.append(Date(timeIntervalSince1970: observed + 901)) }
                for quota in group.windows { if let reset = quota.reset { dates.append(Date(timeIntervalSince1970: reset + 1)) } }
            }
            let limit = now.addingTimeInterval(30 * 60)
            let entries = dates.filter { $0 >= now && $0 <= limit }.sorted().map { GaugeEntry(date: $0, snapshot: model) }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

struct GaugeWidgetView: View {
    let entry: GaugeEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        Group {
            if family == .systemSmall {
                SmallGaugeDashboard(snapshot: entry.snapshot, date: entry.date, accented: renderingMode == .accented)
            } else {
                GaugeDashboard(snapshot: entry.snapshot, date: entry.date, large: family == .systemLarge, accented: renderingMode == .accented)
            }
        }
        .environment(\.colorScheme, .dark) // always dark, as on the Scriptable widget
        .containerBackground(for: .widget) { Color.black }
    }
}

struct TokenGaugeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokenGauge", provider: GaugeTimeline()) { entry in GaugeWidgetView(entry: entry) }
            .configurationDisplayName("Token Gauge")
            .description("Claude, Codex and Grok usage windows, reset times and usage pace.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled() // the dashboards pad themselves so they can use the whole widget
    }
}
