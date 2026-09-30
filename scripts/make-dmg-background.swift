import AppKit

// Finder positions real draggable icons over this artwork. No fake app controls.
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 640, height: 400))
image.lockFocus()
NSColor(calibratedWhite: 0.94, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 640, height: 400).fill()
func label(_ text: String, y: CGFloat, size: CGFloat, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (text as NSString).draw(
        in: NSRect(x: 24, y: y, width: 592, height: 40),
        withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium),
                         .foregroundColor: color, .paragraphStyle: paragraph])
}
label("Make room for your next idea.", y: 322, size: 24, color: .darkGray)
label("Drag Stash into Applications", y: 280, size: 16, color: .darkGray)
NSColor(calibratedWhite: 0.5, alpha: 1).setStroke()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 287, y: 200))
arrow.line(to: NSPoint(x: 351, y: 200))
arrow.move(to: NSPoint(x: 339, y: 212))
arrow.line(to: NSPoint(x: 351, y: 200))
arrow.line(to: NSPoint(x: 339, y: 188))
arrow.lineWidth = 2.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.stroke()
label("Then open Stash from Applications.", y: 55, size: 14, color: .darkGray)
label("You can eject this disk when you’re done.", y: 25, size: 12, color: .gray)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
