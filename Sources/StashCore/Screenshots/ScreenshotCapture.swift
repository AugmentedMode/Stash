import AppKit
import ImageIO
import Darwin

public enum ScreenshotCapture {
    public static let maximumBytes = 20 * 1024 * 1024
    public static func isScreenshot(_ url: URL) -> Bool {
        // macOS marks captures independently of their filename or language.
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }
    public static func clip(data: Data, date: Date = Date()) -> Clip? {
        guard data.count <= maximumBytes,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0, width <= 16000, height <= 16000,
            width * height <= 40_000_000,
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]), png.count <= maximumBytes else {
            return nil
        }
        return Clip(
            createdAt: date, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture",
            kind: .screenshot, text: "Screenshot", items: [[NSPasteboard.PasteboardType.png.rawValue: png]])
    }
    public static func load(_ url: URL) -> Clip? {
        guard isScreenshot(url),
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .creationDateKey]
            ),
            values.isRegularFile == true, let size = values.fileSize, size <= maximumBytes,
            let data = try? Data(contentsOf: url)
        else { return nil }
        return clip(data: data, date: values.creationDate ?? Date())
    }
}
