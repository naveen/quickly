// Renders the app icon: a violet rounded tile with a white bolt.
// Usage: swift Support/make-icon.swift <output.iconset>
import AppKit

let outDir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.09
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.19, yRadius: s * 0.19)
    NSGradient(starting: NSColor(calibratedRed: 0.46, green: 0.40, blue: 1.0, alpha: 1),
               ending: NSColor(calibratedRed: 0.26, green: 0.16, blue: 0.82, alpha: 1))!
        .draw(in: path, angle: -70)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .bold)
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let white = NSImage(size: bolt.size, flipped: false) { r in
            bolt.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let size = white.size
        let origin = NSPoint(x: (s - size.width) / 2, y: (s - size.height) / 2)
        NSColor.black.withAlphaComponent(0.18).set()
        white.draw(in: NSRect(origin: NSPoint(x: origin.x, y: origin.y - s * 0.015), size: size), from: .zero, operation: .sourceOver, fraction: 0.35)
        white.draw(in: NSRect(origin: origin, size: size))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
    try render(points * scale).write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
