import AppKit
import StashCore

extension AppModel {
    /// Synthetic fixtures for browsing QA; never reads user screenshots.
    static func demoImages(now: Date) -> [Clip] {
        (0..<9).compactMap { index in
            let image = NSImage(size: NSSize(width: 720, height: index == 7 ? 820 : 440))
            image.lockFocus()
            let bounds = NSRect(origin: .zero, size: image.size)
            NSColor(calibratedHue: CGFloat(index) / 12 + 0.5, saturation: 0.28, brightness: 0.25, alpha: 1)
                .setFill()
            bounds.fill()
            NSColor.white.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 28, dy: 28), xRadius: 14, yRadius: 14).fill()
            let title = [
                "Dashboard", "Design notes", "Weekly overview", "Color study", "Project board",
                "Reading list", "Analytics", "Long capture", "Workspace",
            ][index]
            (title as NSString).draw(
                at: NSPoint(x: 54, y: image.size.height - 86),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 28, weight: .semibold), .foregroundColor: NSColor.white,
                ])
            for column in 0..<3 {
                NSColor(
                    calibratedHue: CGFloat(index + column) / 12 + 0.5, saturation: 0.25, brightness: 0.7,
                    alpha: 1
                ).setFill()
                NSBezierPath(
                    roundedRect: NSRect(x: 54 + column * 210, y: 65, width: 185, height: 120 + column * 38),
                    xRadius: 9, yRadius: 9
                ).fill()
            }
            image.unlockFocus()
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                let png = rep.representation(using: .png, properties: [:])
            else { return nil }
            return Clip(
                createdAt: now.addingTimeInterval(-Double(index * 180)), sourceName: "Preview",
                sourceBundle: "com.apple.Preview", kind: index < 7 ? .screenshot : .image, text: title,
                items: [[NSPasteboard.PasteboardType.png.rawValue: png]])
        }
    }
}
