import SwiftUI
import AppKit

private func hex(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
}
private let ink = hex(0xF5F5F7)
private let muted = hex(0xB7B7BD)
private let surface = hex(0x1C1C1E)

struct ReviewDial: View {
    let percent: Int
    let label: String
    let clock: String
    let claude: Bool
    var fable: Int? = nil
    var small = false
    let pace: Double
    private var diameter: CGFloat { small ? 40 : 64 }
    private var thickness: CGFloat { small ? 3.5 : 5 }
    private var color: Color { claude ? hex(0xF49A72) : hex(0x87B5FA) }
    private func ring(value: Int, diameter: CGFloat, width: CGFloat, color: Color) -> some View {
        ZStack {
            Circle().inset(by: width / 2).stroke(hex(0x444447), lineWidth: width)
            Circle().inset(by: width / 2).trim(from: 0, to: CGFloat(value) / 100)
                .stroke(LinearGradient(colors: [color, color.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.frame(width: diameter, height: diameter)
    }
    var body: some View {
        VStack(spacing: small ? 2 : 4) {
            ZStack {
                ring(value: percent, diameter: diameter, width: thickness, color: color)
                if let fable {
                    ring(value: fable, diameter: diameter - 2 * (thickness + 2), width: small ? 2.5 : 4, color: hex(0xFFD1A6))
                }
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(hex(0xFF6D78))
                    .frame(width: small ? 1.5 : 1.8, height: thickness - 1.2)
                    .overlay(RoundedRectangle(cornerRadius: 0.5).stroke(hex(0x101012), lineWidth: 0.65))
                    .offset(y: -(diameter - thickness) / 2)
                    .rotationEffect(.degrees(pace * 360))
                Text("\(percent)%")
                    .font(.system(size: small ? 12.5 : 19, weight: .medium, design: .rounded))
                    .foregroundStyle(ink).monospacedDigit()
            }.frame(width: diameter, height: diameter)
            HStack(spacing: 3) {
                Text(label).foregroundStyle(muted)
                if let fable { Text("F \(fable)%").foregroundStyle(hex(0xFFD1A6)) }
            }.font(.system(size: small ? 8.5 : 10, weight: .medium)).lineLimit(1)
            Text(clock).font(.system(size: small ? 9 : 10.5, weight: .regular)).foregroundStyle(muted).lineLimit(1).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }
}
struct ReviewProvider: View {
    let claude: Bool
    var small = false
    var logo: some View {
        ProviderMark(provider: claude ? "claude" : "codex")
            .fill(claude ? hex(0xF49A72) : ink)
            .frame(width: small ? 14 : 18, height: small ? 14 : 18)
    }
    var dials: some View {
        HStack(alignment: .top, spacing: small ? 7 : 8) {
            ReviewDial(percent: claude ? 6 : 52, label: "5H", clock: claude ? "11:20pm" : "1:42am", claude: claude, small: small, pace: claude ? 0.68 : 0.2)
            ReviewDial(percent: claude ? 96 : 43, label: "7D", clock: claude ? "Thu 5:00am" : "Mon 7:29pm", claude: claude, fable: claude ? 10 : nil, small: small, pace: claude ? 0.81 : 0.12)
        }
    }
    var body: some View {
        Group {
            if small { HStack(spacing: 6) { logo; dials } }
            else { VStack(spacing: 7) { logo; dials } }
        }.frame(maxWidth: .infinity)
    }
}
struct ReviewWidget: View {
    var small = false
    var body: some View {
        Group {
            if small {
                VStack(spacing: 8) { ReviewProvider(claude: true, small: true); ReviewProvider(claude: false, small: true) }
            } else {
                HStack(spacing: 18) { ReviewProvider(claude: true); ReviewProvider(claude: false) }
            }
        }.padding(12)
            .frame(width: small ? 164 : 344, height: 164)
            .background(surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.12), lineWidth: 0.5))
    }
}
struct ReviewIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(surface)
            Circle().inset(by: 14).stroke(hex(0x444447), lineWidth: 4.5)
            Circle().inset(by: 14).trim(from: 0, to: 0.72)
                .stroke(LinearGradient(colors: [hex(0xED8157), hex(0xF4AF78)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 4.5, lineCap: .round)).rotationEffect(.degrees(-90))
            RoundedRectangle(cornerRadius: 0.5).fill(hex(0xFF6D78))
                .frame(width: 1.8, height: 3.2).overlay(RoundedRectangle(cornerRadius: 0.5).stroke(hex(0x101012), lineWidth: 0.65))
                .offset(y: -18).rotationEffect(.degrees(96))
        }.frame(width: 64, height: 64)
    }
}
struct ProposalBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 9) {
                Text("PROPOSAL 01").font(.system(size: 12, weight: .semibold)).tracking(2.5).foregroundStyle(hex(0xF49A72))
                Text("Four quiet gauges. Clearer numbers.").font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(ink)
            }
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("MEDIUM · 344 × 164 PT").font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(muted)
                    ReviewWidget().scaleEffect(2, anchor: .topLeading).frame(width: 688, height: 328, alignment: .topLeading)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("SMALL · 164 × 164 PT").font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(muted)
                    ReviewWidget(small: true).scaleEffect(2, anchor: .topLeading).frame(width: 328, height: 328, alignment: .topLeading)
                }
            }
            HStack(spacing: 20) {
                ReviewIcon().scaleEffect(1.5).frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 8) {
                    Text("APP ICON").font(.system(size: 11, weight: .medium)).tracking(1.5).foregroundStyle(muted)
                    Text("One ring + the red tick.").font(.system(size: 17, weight: .medium)).foregroundStyle(ink)
                    Text("No needle or central hub.").font(.system(size: 14)).foregroundStyle(muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("Outer weekly track · overall usage").foregroundStyle(hex(0xF49A72))
                    Text("Inner weekly track · Fable").foregroundStyle(hex(0xFFD1A6))
                    Text("Clock times use the Mac’s local timezone.").foregroundStyle(muted)
                }.font(.system(size: 13))
            }
        }.padding(40).frame(width: 1128, height: 620)
            .background(LinearGradient(colors: [hex(0x111113), hex(0x1B1715)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, .dark)
    }
}
@main struct RenderProposal {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: "/Users/jksim/TokenGauge/DesignReview", isDirectory: true)
        func save<V: View>(_ view: V, name: String, scale: CGFloat) throws {
            let renderer = ImageRenderer(content: view)
            renderer.scale = scale
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Render failed") }
            try png.write(to: root.appendingPathComponent(name + ".png"))
        }
        try save(ProposalBoard(), name: "proposal-01", scale: 1.5)
        try save(ReviewWidget().environment(\.colorScheme, .dark), name: "medium-proposed", scale: 2)
        try save(ReviewWidget(small: true).environment(\.colorScheme, .dark), name: "small-proposed", scale: 2)
        try save(ReviewIcon(), name: "icon-proposed", scale: 4)
    }
}
