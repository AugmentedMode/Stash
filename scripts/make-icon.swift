import AppKit
let destination = URL(fileURLWithPath: "dist/Stash.iconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
        NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 28, y: 28, width: 968, height: 968), xRadius: 225, yRadius: 225)
            .fill()
        for (i, y) in [CGFloat(265), CGFloat(375), CGFloat(485)].enumerated() {
            let path = NSBezierPath(
                roundedRect: NSRect(x: 257, y: y, width: 510, height: 280), xRadius: 56, yRadius: 56)
            NSColor(calibratedRed: 0.76, green: 0.78, blue: 1.0, alpha: CGFloat(i + 1) / 3).setFill()
            path.fill()
            NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.24, alpha: 1).setStroke()
            path.lineWidth = 22
            path.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(
            to: destination.appendingPathComponent(filename))
    }
}
