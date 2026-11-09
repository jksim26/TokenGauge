import SwiftUI
import WidgetKit

struct GaugeEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    var offline = false
}
struct GaugeTimeline: TimelineProvider {
    func placeholder(in context: Context) -> GaugeEntry { .init(date: Date(), snapshot: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (GaugeEntry) -> Void) {
        Task {
            do { completion(.init(date: Date(), snapshot: try await Bridge.fetch())) }
            catch { completion(.init(date: Date(), snapshot: Bridge.cached, offline: true)) }
        }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GaugeEntry>) -> Void) {
        Task {
            let model: UsageSnapshot
            var offline = false
            do { model = try await Bridge.fetch() }
            catch { model = Bridge.cached; offline = true }
            let now = Date(), next = now.addingTimeInterval(180)
            var dates = [now]
            for group in model.groups {
                if let observed = group.observedAt {
                    let staleDate = Date(timeIntervalSince1970: observed + 901)
                    if staleDate > now && staleDate < next { dates.append(staleDate) }
                }
                for quota in group.windows {
                    if let reset = quota.reset {
                        let resetDate = Date(timeIntervalSince1970: reset + 1)
                        if resetDate > now && resetDate < next { dates.append(resetDate) }
                    }
                }
            }
            let entries = dates.sorted().map { GaugeEntry(date: $0, snapshot: model, offline: offline) }
            completion(Timeline(entries: entries, policy: .after(next)))
        }
    }
}
struct GaugeWidgetView: View {
    let entry: GaugeEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode
    var body: some View {
        Group {
            if family == .systemSmall {
                SmallGaugeDashboard(snapshot: entry.snapshot, date: entry.date, offline: entry.offline, accented: renderingMode == .accented)
            } else {
                GaugeDashboard(snapshot: entry.snapshot, date: entry.date, large: family == .systemLarge, offline: entry.offline, accented: renderingMode == .accented)
            }
        }
            .containerBackground(for: .widget) { Rectangle().fill(.ultraThinMaterial) }
            .widgetURL(URL(string: "tokengauge://open"))
    }
}
@main
struct TokenGaugeWidget: Widget {
    let kind = "TokenGauge"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GaugeTimeline()) { entry in GaugeWidgetView(entry: entry) }
            .configurationDisplayName("Token Gauge")
            .description("Claude, Codex and Grok usage windows, reset times and usage pace.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .containerBackgroundRemovable(true)
    }
}
