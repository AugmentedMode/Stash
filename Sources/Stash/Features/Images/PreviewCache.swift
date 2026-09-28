import AppKit
import SwiftUI
import ImageIO
import StashCore

@MainActor
enum PreviewCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()
    private static var inFlight: [String: Task<CGImage?, Never>] = [:]

    static func cached(_ clip: Clip) -> NSImage? {
        for pixels in [2000, 1200, 320] {
            if let image = images.object(forKey: "\(clip.fingerprint)-\(pixels)" as NSString) { return image }
        }
        return nil
    }
    static func load(_ clip: Clip, pixels: Int) async -> NSImage? {
        let key = "\(clip.fingerprint)-\(pixels)"
        if let cached = images.object(forKey: key as NSString) { return cached }
        guard
            let data = clip.items.lazy.compactMap({
                $0[NSPasteboard.PasteboardType.png.rawValue] ?? $0[NSPasteboard.PasteboardType.tiff.rawValue]
            }).first
        else { return nil }
        let task: Task<CGImage?, Never>
        if let existing = inFlight[key] {
            task = existing
        } else {
            task = Task.detached(priority: .userInitiated) {
                guard
                    let source = CGImageSourceCreateWithData(
                        data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
                else { return nil as CGImage? }
                return CGImageSourceCreateThumbnailAtIndex(
                    source, 0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: pixels,
                        kCGImageSourceShouldCacheImmediately: true,
                    ] as CFDictionary)
            }
            inFlight[key] = task
        }
        let cgImage = await task.value
        inFlight[key] = nil
        // A cancelled view does not cancel a decode another view is awaiting.
        guard let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        images.setObject(image, forKey: key as NSString, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}
