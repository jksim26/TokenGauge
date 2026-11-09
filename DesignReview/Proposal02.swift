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
    private var diameter: CGFloat { small ? 44 : 72 }
    private var thickness: CGFloat { small ? 3 : 4 }
    private var color: Color { claude ? (label == "5H" ? hex(0xFFC276) : hex(0xF77835)) : (label == "5H" ? hex(0x84E8FF) : hex(0x438CFF)) }
    private var endColor: Color { claude ? (label == "5H" ? hex(0xFF873F) : hex(0xC94916)) : (label == "5H" ? hex(0x409DFF) : hex(0x3751D8)) }
    private func ring(value: Int, diameter: CGFloat, width: CGFloat, color: Color) -> some View {
        ZStack {
            Circle().inset(by: width / 2).stroke(.white.opacity(0.13), lineWidth: width)
            Circle().inset(by: width / 2).trim(from: 0, to: CGFloat(value) / 100)
                .stroke(LinearGradient(colors: [color, endColor], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.frame(width: diameter, height: diameter)
    }
    var body: some View {
        VStack(spacing: small ? 2 : 4) {
            ZStack {
                ring(value: percent, diameter: diameter, width: thickness, color: color)
                if let fable {
                    ring(value: fable, diameter: diameter - 2 * (thickness + 3), width: small ? 2 : 2.5, color: hex(0xFFD6A0))
                }
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(hex(0xFF6D78))
                    .frame(width: small ? 1.5 : 1.8, height: thickness - 1.2)
                    .overlay(RoundedRectangle(cornerRadius: 0.5).stroke(hex(0x101012), lineWidth: 0.65))
                    .offset(y: -(diameter - thickness) / 2)
                    .rotationEffect(.degrees(pace * 360))
                VStack(spacing: 1) {
                    Text("\(percent)%")
                        .font(.system(size: small ? 11 : 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                    if let fable {
                        Text("\(fable)%").font(.system(size: small ? 8 : 11, weight: .medium, design: .rounded)).foregroundStyle(hex(0xFFD6A0))
                    }
                }.monospacedDigit()
            }.frame(width: diameter, height: diameter)
            HStack(spacing: 3) {
                Text(fable == nil ? label : "7D & F").foregroundStyle(muted)
                
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
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.38), lineWidth: 0.6))
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
        VStack(alignment: .leading, spacing: 24) {
            Text("PROPOSAL 02 · TRANSLUCENT + VIBRANT").font(.system(size: 12, weight: .semibold)).tracking(2).foregroundStyle(ink)
            Text("More space inside. More colour around.").font(.system(size: 28, weight: .medium, design: .rounded)).foregroundStyle(ink)
            ReviewWidget().scaleEffect(2.5, anchor: .topLeading).frame(width: 860, height: 410, alignment: .topLeading)
            HStack(alignment: .top, spacing: 50) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("5H · brighter peach / sky blue")
                    Text("7D · deeper orange / cobalt")
                    Text("Visible light-to-dark gradients")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly · thinner nested tracks")
                    Text("96% overall + 10% Fable inside")
                    Text("7D & F · one label below")
                }
            }.font(.system(size: 15)).foregroundStyle(ink)
            Text("Surface illustration over a backdrop — native macOS glass to be verified in the widget.").font(.system(size: 12)).foregroundStyle(ink.opacity(0.8))
        }.padding(40).frame(width: 940, height: 690)
        .background {
            ZStack {
                LinearGradient(colors: [hex(0x17232E), hex(0x566165), hex(0x352C35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(hex(0x6599AD).opacity(0.5)).frame(width: 650,height: 350).blur(radius: 85).offset(x: -220, y: 0)
                Ellipse().fill(hex(0xB97C5E).opacity(0.35)).frame(width: 500,height: 360).blur(radius: 85).offset(x: 350, y: 160)
            }
        }.environment(\.colorScheme, .dark)
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
        try save(ProposalBoard(), name: "proposal-02", scale: 1.5)
        try save(ReviewWidget().environment(\.colorScheme, .dark), name: "medium-proposed", scale: 2)
        try save(ReviewWidget(small: true).environment(\.colorScheme, .dark), name: "small-proposed", scale: 2)
        try save(ReviewIcon(), name: "icon-proposed", scale: 4)
    }
}
