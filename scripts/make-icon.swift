import AppKit

// Draws the app icon on Apple's 1024-point macOS grid: an 824-point rounded body with a
// soft shadow, carrying the same stacked-layers mark as the menu bar icon.
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dist/Stash.iconset")
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// A diamond (one isometric layer) with rounded corners, centered on `center`.
func layer(center: CGPoint, width: CGFloat, height: CGFloat, radius: CGFloat) -> CGPath {
    let top = CGPoint(x: center.x, y: center.y + height / 2)
    let right = CGPoint(x: center.x + width / 2, y: center.y)
    let bottom = CGPoint(x: center.x, y: center.y - height / 2)
    let left = CGPoint(x: center.x - width / 2, y: center.y)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: (left.x + top.x) / 2, y: (left.y + top.y) / 2))
    path.addArc(tangent1End: top, tangent2End: right, radius: radius)
    path.addArc(tangent1End: right, tangent2End: bottom, radius: radius)
    path.addArc(tangent1End: bottom, tangent2End: left, radius: radius)
    path.addArc(tangent1End: left, tangent2End: top, radius: radius)
    path.closeSubpath()
    return path
}

/// The lower half of a layer, drawn as an open chevron like the menu bar symbol.
func chevron(center: CGPoint, width: CGFloat, height: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x - width / 2, y: center.y))
    path.addLine(to: CGPoint(x: center.x, y: center.y - height / 2))
    path.addLine(to: CGPoint(x: center.x + width / 2, y: center.y))
    return path
}

/// `scale` converts shadows, which Core Graphics does not scale with the drawing.
func drawIcon(in context: CGContext, scale: CGFloat) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the body, as on other macOS app icons.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: rgb(0, 0, 0, 0.38))
    context.addPath(bodyPath)
    context.setFillColor(rgb(24, 26, 48))
    context.fillPath()
    context.restoreGState()

    // Deep indigo body, lighter at the top.
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    let background = CGGradient(
        colorsSpace: space, colors: [rgb(63, 66, 128), rgb(33, 35, 71), rgb(17, 18, 36)] as CFArray,
        locations: [0, 0.55, 1])!
    context.drawLinearGradient(
        background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // A soft lavender glow behind the mark.
    let glow = CGGradient(
        colorsSpace: space, colors: [rgb(160, 168, 255, 0.34), rgb(160, 168, 255, 0)] as CFArray,
        locations: [0, 1])!
    context.drawRadialGradient(
        glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0, endCenter: CGPoint(x: 512, y: 560),
        endRadius: 360, options: [])
    // Glass sheen across the top half.
    let sheen = CGGradient(
        colorsSpace: space, colors: [rgb(255, 255, 255, 0.10), rgb(255, 255, 255, 0)] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: [])
    context.restoreGState()

    // Hairline edge highlight.
    context.saveGState()
    context.addPath(
        CGPath(
            roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 183, cornerHeight: 183, transform: nil))
    context.setStrokeColor(rgb(255, 255, 255, 0.14))
    context.setLineWidth(4)
    context.strokePath()
    context.restoreGState()

    let width: CGFloat = 470
    let height: CGFloat = 262
    let stroke: CGFloat = 46
    let top = CGPoint(x: 512, y: 612)

    // Lower layers: open chevrons that fade as they recede.
    context.saveGState()
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setLineWidth(stroke)
    for (offset, alpha) in [(CGFloat(206), CGFloat(0.42)), (CGFloat(103), CGFloat(0.72))] {
        context.addPath(chevron(center: CGPoint(x: top.x, y: top.y - offset), width: width, height: height))
        context.setStrokeColor(rgb(196, 200, 255, alpha))
        context.strokePath()
    }
    context.restoreGState()

    // Top layer: a filled, lit tile.
    let tile = layer(center: top, width: width + stroke, height: height + stroke * 0.56, radius: 40)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -10 * scale), blur: 30 * scale, color: rgb(8, 9, 30, 0.55))
    context.addPath(tile)
    context.setFillColor(rgb(200, 204, 255))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(tile)
    context.clip()
    let face = CGGradient(
        colorsSpace: space, colors: [rgb(246, 247, 255), rgb(196, 200, 255), rgb(156, 162, 245)] as CFArray,
        locations: [0, 0.55, 1])!
    context.drawLinearGradient(
        face, start: CGPoint(x: 512, y: top.y + height / 2 + 24),
        end: CGPoint(x: 512, y: top.y - height / 2 - 24),
        options: [])
    context.restoreGState()
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let context = CGContext(
            data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        context.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
        drawIcon(in: context, scale: CGFloat(px) / 1024)
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
            .write(to: destination.appendingPathComponent(filename))
    }
}
