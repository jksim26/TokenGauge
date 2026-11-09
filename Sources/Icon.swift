import AppKit

@main
struct IconMaker {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let size = base * scale
                let image = NSImage(size: NSSize(width: size, height: size))
                image.lockFocus()
                let transform = NSAffineTransform()
                transform.scale(by: CGFloat(size) / 1024); transform.concat()
                let bounds = NSRect(x: 82, y: 82, width: 860, height: 860)
                let tile = NSBezierPath(roundedRect: bounds, xRadius: 192, yRadius: 192)
                NSGradient(starting: NSColor(red: 0.13, green: 0.23, blue: 0.27, alpha: 1), ending: NSColor(red: 0.055, green: 0.085, blue: 0.13, alpha: 1))!.draw(in: tile, angle: -65)
                let center = NSPoint(x: 512, y: 505)
                let track = NSBezierPath(ovalIn: NSRect(x: 247, y: 240, width: 530, height: 530))
                track.lineWidth = 76
                NSColor(white: 1, alpha: 0.13).setStroke(); track.stroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: 265, startAngle: 90, endAngle: -154, clockwise: true)
                arc.lineWidth = 76; arc.lineCapStyle = .round
                NSColor(red: 0.35, green: 0.87, blue: 0.65, alpha: 1).setStroke(); arc.stroke()
                let tick = NSBezierPath()
                let angle = CGFloat(-20) * .pi / 180
                tick.move(to: NSPoint(x: center.x + cos(angle) * 223, y: center.y + sin(angle) * 223))
                tick.line(to: NSPoint(x: center.x + cos(angle) * 307, y: center.y + sin(angle) * 307))
                tick.lineWidth = 24; tick.lineCapStyle = .round
                NSColor(red: 1, green: 0.40, blue: 0.40, alpha: 1).setStroke(); tick.stroke()
                image.unlockFocus()
                guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
                let suffix = scale == 2 ? "@2x" : ""
                try png.write(to: root.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
            }
        }
    }
}
