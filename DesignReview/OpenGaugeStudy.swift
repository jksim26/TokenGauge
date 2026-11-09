import SwiftUI
import AppKit

private func hex(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
}
private let palette = Int(CommandLine.arguments.dropFirst().first ?? "1") ?? 1
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
    private var thickness: CGFloat { small ? 5 : 8 }
    private var color: Color { claude ? (label == "5H" ? hex(0xFFE0A0) : hex(0xFFB45D)) : (label == "5H" ? hex(0xB8F8FF) : hex(0x81C8FF)) }
    private var endColor: Color { claude ? (label == "5H" ? hex(0xFF742A) : hex(0xC83C12)) : (label == "5H" ? hex(0x218BFF) : hex(0x3438C9)) }
    private func ring(value: Int, diameter: CGFloat, width: CGFloat, color: Color) -> some View {
        let progress = CGFloat(value) / 100
        let radius = (diameter - width) / 2
        return ZStack {
            Circle().inset(by: width / 2).trim(from: 0, to: 300.0 / 360).stroke(.white.opacity(0.13), style: StrokeStyle(lineWidth: width, lineCap: .butt)).rotationEffect(.degrees(-60))
            if value > 0 {
                Canvas { context, size in
                    let isFable = width < 5
                    let weekly = label == "7D"
                    let stops: [(Double, UInt32)]
                    if palette == 1 {
                        stops = isFable ? [(0,0xB4F5CF),(1,0x4CC9A3)] : [(0,0x55E68B),(0.45,0xA5E25B),(0.7,0xFFD34E),(0.85,0xFF943D),(1,0xF54A54)]
                    } else if palette == 2 {
                        stops = isFable ? [(0,0xFFE3A0),(1,0xE5B34A)] : claude ? (weekly ? [(0,0xFFB369),(0.5,0xF68B43),(1,0xDD552C)] : [(0,0xFFD69A),(1,0xFF9652)]) : (weekly ? [(0,0x84BDFF),(0.5,0x518FEF),(1,0x425CD2)] : [(0,0xB2EAFF),(1,0x57B7F5)])
                    } else {
                        stops = isFable ? [(0,0xD6E8FF),(1,0xA6B8F4)] : claude ? (weekly ? [(0,0x68DBBE),(1,0x159E91)] : [(0,0xC4FFE2),(1,0x66DDBE)]) : (weekly ? [(0,0xB9A0F6),(1,0x7653CD)] : [(0,0xE2D3FF),(1,0xB6A0F4)])
                    }
                    let steps = max(40, Int(progress * 720))
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let end = (-60 + Double(progress) * 300) * Double.pi / 180
                    func point(_ r: CGFloat, _ a: Double) -> CGPoint { CGPoint(x: center.x + r * cos(a), y: center.y + r * sin(a)) }
                    let outer = radius + width / 2
                    let inner = radius - width / 2
                    let bulge = min(width * 0.19, radius * Double(progress) * Double.pi * 0.2)
                    var shape = Path()
                    shape.move(to: point(outer, -.pi / 3))
                    shape.addArc(center: center, radius: outer, startAngle: .degrees(-60), endAngle: .radians(end), clockwise: false)
                    let tip = point(radius, end)
                    shape.addQuadCurve(to: point(inner, end), control: CGPoint(x: tip.x - sin(end) * bulge * 2, y: tip.y + cos(end) * bulge * 2))
                    shape.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .degrees(-60), clockwise: true)
                    let start = point(radius, -.pi / 3)
                    shape.addQuadCurve(to: point(outer, -.pi / 3), control: CGPoint(x: start.x - sin(Double.pi / 3) * bulge * 2, y: start.y - cos(Double.pi / 3) * bulge * 2))
                    shape.closeSubpath()
                    context.clip(to: shape)
                    let base = NSColor(hex(stops.last!.1)).usingColorSpace(.deviceRGB)!
                    let head = NSColor(hex(stops.first!.1)).usingColorSpace(.deviceRGB)!
                    context.fill(shape, with: .color(Color(base)))
                    for i in 0..<steps {
                        let position = Double(i) / Double(steps - 1)
                        let ramp = max(0, min(1, (position - 0.84) / 0.16))
                        let blend = ramp * ramp * (3 - 2 * ramp)
                        let shade = Color(red: base.redComponent + (head.redComponent - base.redComponent) * blend,
                                          green: base.greenComponent + (head.greenComponent - base.greenComponent) * blend,
                                          blue: base.blueComponent + (head.blueComponent - base.blueComponent) * blend)
                        var segment = Path()
                        segment.addArc(center: center, radius: radius,
                            startAngle: .degrees(-60 + Double(progress) * 300 * Double(i) / Double(steps)),
                            endAngle: .degrees(-60 + Double(progress) * 300 * Double(i + 1) / Double(steps)), clockwise: false)
                        context.stroke(segment, with: .color(shade), style: StrokeStyle(lineWidth: width + 1, lineCap: .round))
                    }
                    var sheen = Path()
                    sheen.addArc(center: CGPoint(x: center.x - 0.15, y: center.y - 0.3), radius: radius + width * 0.18,
                        startAngle: .degrees(-60), endAngle: .radians(end), clockwise: false)
                    var softLight = context
                    softLight.addFilter(.blur(radius: width * 0.1))
                    softLight.stroke(sheen, with: .linearGradient(Gradient(colors: [.white.opacity(0.36), .white.opacity(0.04), .white.opacity(0.18)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), style: StrokeStyle(lineWidth: width * 0.3, lineCap: .round))
                    context.stroke(shape, with: .linearGradient(Gradient(colors: [.white.opacity(0.38), .white.opacity(0.06)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), lineWidth: 0.35)

                }

            }
        }.frame(width: diameter, height: diameter)
    }
    var body: some View {
        VStack(spacing: small ? 2 : 4) {
            ZStack {
                ring(value: percent, diameter: diameter, width: thickness, color: color)
                if let fable {
                    ring(value: fable, diameter: diameter - 2 * (thickness + 0.5), width: small ? 1.8 : 2.5, color: hex(0xFFD6A0))
                }
                Capsule()
                    .fill(hex(0xFF4558))
                    .frame(width: small ? 1.6 : 2, height: fable != nil ? thickness + 0.5 + 2.5 : thickness)
                    .shadow(color: .black.opacity(0.55), radius: 0.6)
                    .offset(y: -(diameter - (fable != nil ? thickness + 0.5 + 2.5 : thickness)) / 2)
                    .rotationEffect(.degrees(30 + pace * 300))
                Text(fable == nil ? label : "7D & F")
                    .font(.system(size: small ? 6 : 8, weight: .semibold))
                    .foregroundStyle(muted)
                    .offset(y: -diameter / 2 + thickness / 2)
                VStack(spacing: 1) {
                    Text("\(percent)%")
                        .font(.system(size: small ? 10 : 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink)
                    if let fable {
                        Text("\(fable)%").font(.system(size: small ? 7 : 8, weight: .regular, design: .rounded)).foregroundStyle(hex(palette == 1 ? 0xB4F5CF : palette == 2 ? 0xFFE3A0 : 0xD6E8FF).opacity(0.8))
                    }
                }.monospacedDigit()
            }.frame(width: diameter, height: diameter)
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
                .stroke(LinearGradient(colors: [hex(0xED8157), hex(0xF4AF78)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 4.5, lineCap: .round)).rotationEffect(.degrees(-60))
            RoundedRectangle(cornerRadius: 0.5).fill(hex(0xFF6D78))
                .frame(width: 1.8, height: 3.2).overlay(RoundedRectangle(cornerRadius: 0.5).stroke(hex(0x101012), lineWidth: 0.65))
                .offset(y: -18).rotationEffect(.degrees(96))
        }.frame(width: 64, height: 64)
    }
}
struct ProposalBoard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("OPTION 02 · OPEN GAUGES + SOFT SHEEN").font(.system(size: 12, weight: .semibold)).tracking(2).foregroundStyle(ink)
            Text("Labels at twelve. A softer liquid finish.").font(.system(size: 28, weight: .medium, design: .rounded)).foregroundStyle(ink)
            ReviewWidget().scaleEffect(2.5, anchor: .topLeading).frame(width: 860, height: 410, alignment: .topLeading)
            HStack(alignment: .top, spacing: 50) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(palette == 1 ? "Colour follows usage: green to amber to red" : "5H · lighter tones / 7D · deeper tones")
                    Text(palette == 1 ? "Fable · pale mint, independently readable" : palette == 2 ? "Fable · pale gold against orange" : "Fable · icy blue against teal")
                    Text("Open track · 1 o’clock to 11 o’clock")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Convex ends + restrained glass highlights")
                    Text("Fable percentage · smaller and quieter")
                    Text("One red marker crosses both tracks")
                }
            }.font(.system(size: 15)).foregroundStyle(ink)
            Text("Shape and colour proposal · smaller percentages · dark mode").font(.system(size: 12)).foregroundStyle(ink.opacity(0.8))
        }.padding(40).frame(width: 940, height: 690)
        .background {
            ZStack {
                LinearGradient(colors: [hex(0x080E17), hex(0x171F2A), hex(0x19151E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(hex(0x35526C).opacity(0.25)).frame(width: 650,height: 350).blur(radius: 85).offset(x: -220, y: 0)
                Ellipse().fill(hex(0x5B3F36).opacity(0.2)).frame(width: 500,height: 360).blur(radius: 85).offset(x: 350, y: 160)
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
        try save(ProposalBoard(), name: "open-gauge-study", scale: 1.5)
        try save(ReviewWidget().environment(\.colorScheme, .dark), name: "medium-proposed", scale: 2)
        try save(ReviewWidget(small: true).environment(\.colorScheme, .dark), name: "small-proposed", scale: 2)
        try save(ReviewIcon(), name: "icon-proposed", scale: 4)
    }
}
