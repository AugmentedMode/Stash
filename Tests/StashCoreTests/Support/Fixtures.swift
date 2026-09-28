import AppKit
import StashCore

final class StashCoreTests {}

extension StashCoreTests {
    func screenshotData() -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 12, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
        return bitmap.representation(using: .png, properties: [:])!
    }
    func markScreenshot(_ url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        let result = data.withUnsafeBytes {
            setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, data.count, 0, 0)
        }
        XCTAssertEqual(result, 0)
    }
    func board() -> NSPasteboard { NSPasteboard.withUniqueName() }
    func clip(_ text: String, pinned: Bool = false, date: Date = Date()) -> Clip {
        Clip(createdAt: date, sourceName: "Notes", kind: ClipKind.classify(text), text: text, pinned: pinned)
    }
}
