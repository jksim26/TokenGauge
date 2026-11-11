import SwiftUI
import AppKit

@main
struct Render {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let singapore = TimeZone(identifier: "Asia/Singapore")!
        let sample = ISO8601DateFormatter().date(from: "2026-10-29T15:59:00Z")!.timeIntervalSince1970
        precondition(ResetTime.string(epoch: sample, weekly: false, timeZone: singapore) == "11:59pm")
        precondition(ResetTime.string(epoch: sample - 0.04, weekly: false, timeZone: singapore) == "11:59pm")
        precondition(ResetTime.string(epoch: sample, weekly: true, timeZone: singapore) == "Thu 11:59pm")
        precondition(ResetTime.string(epoch: nil, weekly: true, timeZone: singapore) == "—")
        let data = try Data(contentsOf: URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Token Gauge/snapshot.json"))
        let snapshot = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        for appearance in ["dark", "light", "accented"] {
          for size in ["small", "medium", "large"] {
            let view = Group {
                if size == "small" { SmallGaugeDashboard(snapshot: snapshot, accented: appearance == "accented") }
                else { GaugeDashboard(snapshot: snapshot, large: size == "large", accented: appearance == "accented") }
            }
                .frame(width: size == "small" ? 170 : 364, height: size == "large" ? 382 : 170)
                .background(appearance == "light" ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.black), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.18)))
                .environment(\.colorScheme, appearance == "light" ? .light : .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to render") }
            let suffix = appearance == "dark" ? "" : "-\(appearance)"
            try png.write(to: URL(fileURLWithPath: "Previews/\(size)\(suffix).png"))
          }
        }
    }
}
