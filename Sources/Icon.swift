import AppKit

// Draws the Token Gauge mark ("Pace Gate": a gauge ring open at the top with the pace dash inside).
// Usage: icon-maker <iconset dir> [<opaque 1024 px PNG for iOS>]
@main
struct IconMaker {
    static let ink = CGColor(srgbRed: 0xE8 / 255.0, green: 0xE9 / 255.0, blue: 0xE4 / 255.0, alpha: 1)
    static let pace = CGColor(srgbRed: 0xFF / 255.0, green: 0x66 / 255.0, blue: 0x5E / 255.0, alpha: 1)
    static let surface = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

    /// `tile` draws the rounded Mac tile on a clear canvas; otherwise the colour fills the square (iOS masks it).
    static func png(size: Int, tile: Bool) -> Data {
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: (tile ? CGImageAlphaInfo.premultipliedLast : .noneSkipLast).rawValue)!
        context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
        context.setFillColor(surface)
        if tile {
            context.addPath(CGPath(roundedRect: CGRect(x: 82, y: 82, width: 860, height: 860), cornerWidth: 192, cornerHeight: 192, transform: nil))
            context.fillPath()
        } else {
            context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        }
        // The mark is drawn on a 256 grid: ring radius 80, stroke 24, dash from 20 to 44 right of centre.
        let unit: CGFloat = tile ? 2.7 : 3.2
        let center = CGPoint(x: 512, y: 512)
        context.setLineWidth(24 * unit)
        context.setLineCap(.round)
        context.addArc(center: center, radius: 80 * unit, startAngle: 120 * .pi / 180, endAngle: 60 * .pi / 180, clockwise: false)
        context.setStrokeColor(ink)
        context.strokePath()
        context.move(to: CGPoint(x: center.x + 20 * unit, y: center.y))
        context.addLine(to: CGPoint(x: center.x + 44 * unit, y: center.y))
        context.setStrokeColor(pace)
        context.strokePath()
        guard let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
        return data
    }

    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                try png(size: base * scale, tile: true).write(to: root.appendingPathComponent("icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"))
            }
        }
        if CommandLine.arguments.count > 2 {
            try png(size: 1024, tile: false).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        }
    }
}
