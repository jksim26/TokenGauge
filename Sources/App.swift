import SwiftUI
import WidgetKit
import AppKit

@MainActor
class GaugeStore: ObservableObject {
    @Published var snapshot = Bridge.cached
    @Published var offline = false
    @Published var busy = false
    func load(refresh: Bool = false) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            snapshot = try await Bridge.fetch(refresh: refresh); offline = false
            if refresh { WidgetCenter.shared.reloadTimelines(ofKind: "TokenGauge") }
        } catch { offline = true }
    }
}
struct ContentView: View {
    @StateObject var store = GaugeStore()
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Token Gauge").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("Your usage, at a glance.").foregroundStyle(.secondary)
                }
                Spacer()
                Button { Task { await store.load(refresh: true) } } label: {
                    Label(store.busy ? "Updating…" : "Refresh", systemImage: "arrow.clockwise")
                }.disabled(store.busy)
            }
            GaugeDashboard(snapshot: store.snapshot, offline: store.offline)
                .padding(20).frame(height: 192)
                .modifier(GaugeGlassSurface())
            VStack(alignment: .leading, spacing: 13) {
                Label("Add the native widget", systemImage: "square.grid.2x2").font(.headline)
                Text("Open Notification Centre by clicking the date and time in the menu bar. Choose Edit Widgets, search for Token Gauge, then add the small, medium or large widget. All sizes show usage gauges and local reset times.")
                Divider()
                Label("Accounts refresh every three minutes", systemImage: "arrow.trianglehead.2.clockwise.rotate.90").font(.headline)
                Text("Claude uses your existing Claude Desktop sign-in, with Claude Code as a fallback. Codex uses its signed-in CLI. Grok shows the weekly Grok and Cursor pool that Grok Bot last displayed; open Grok Bot to refresh it. The local helper keeps checking after you close this window. If a sign-in expires, open the app that owns it to renew it.")
                Label("macOS schedules widget updates", systemImage: "clock").font(.headline)
                Text("The widget requests updates every three minutes; macOS may update it less often. Refresh requests a new timeline. A clock symbol means the report is over 15 minutes old. Expired windows need a new report.")
                ForEach(store.snapshot.groups) { group in
                    if let message = group.message { Text("\(group.title): \(message)").foregroundStyle(.orange) }
                }
                if store.offline { Text("The local helper is offline. Run Install.command from the TokenGauge folder to restore it.").foregroundStyle(.orange) }
            }.font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Local helper · no developer account required by this build").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Button("Open data folder") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Token Gauge"))
                }.font(.system(size: 11))
            }
        }.padding(28).frame(width: 500)
        .task {
            await store.load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !Task.isCancelled { await store.load() }
            }
        }
        .onOpenURL { _ in NSApp.activate(ignoringOtherApps: true); Task { await store.load(refresh: true) } }
    }
}
@main
struct TokenGaugeApp: App {
    var body: some Scene {
        Window("Token Gauge", id: "main") { ContentView() }
            .windowResizability(.contentSize)
    }
}
