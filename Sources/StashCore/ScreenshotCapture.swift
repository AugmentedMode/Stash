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
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]), png.count <= maximumBytes else { return nil }
        return Clip(createdAt: date, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture", kind: .screenshot, text: "Screenshot", items: [[NSPasteboard.PasteboardType.png.rawValue: png]])
    }
    public static func load(_ url: URL) -> Clip? {
        guard isScreenshot(url), let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .creationDateKey]),
              values.isRegularFile == true, let size = values.fileSize, size <= maximumBytes,
              let data = try? Data(contentsOf: url) else { return nil }
        return clip(data: data, date: values.creationDate ?? Date())
    }
}

/// Watches only the chosen save folder. File reads and image decoding stay off the UI thread.
public final class ScreenshotObserver {
    private let queue = DispatchQueue(label: "app.stash.screenshots", qos: .utility)
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var seen = Set<URL>()
    private var began = Date()
    public init() {}
    public func start(folder: URL, receive: @escaping (Clip) -> Void, failure: @escaping () -> Void) {
        queue.async { [self] in
            stopOnQueue()
            let descriptor = open(folder.path, O_EVTONLY)
            guard descriptor >= 0, let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
                if descriptor >= 0 { close(descriptor) }
                DispatchQueue.main.async(execute: failure); return
            }
            seen = Set(urls); began = Date()
            let watch = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete, .revoke], queue: queue)
            watch.setCancelHandler { close(descriptor) }
            watch.setEventHandler { [weak self] in
                guard let self else { return }
                if !watch.data.intersection([.rename, .delete, .revoke]).isEmpty {
                    self.stopOnQueue(); DispatchQueue.main.async(execute: failure); return
                }
                self.schedule(folder: folder, attempt: 0, receive: receive)
            }
            source = watch; watch.resume()
        }
    }
    private func schedule(folder: URL, attempt: Int, receive: @escaping (Clip) -> Void) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.source != nil,
                  let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]) else { return }
            self.seen.formIntersection(Set(urls))
            let ordered = urls.sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return lhs < rhs
            }
            for url in ordered where !self.seen.contains(url) {
                guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate, date >= self.began else { self.seen.insert(url); continue }
                if let clip = ScreenshotCapture.load(url) {
                    self.seen.insert(url)
                    DispatchQueue.main.async { receive(clip) }
                } else if attempt == 4 { self.seen.insert(url) }
            }
            if attempt < 4 { self.schedule(folder: folder, attempt: attempt + 1, receive: receive) }
        }
        pending = work; queue.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    public func stop() { queue.async { [self] in stopOnQueue() } }
    private func stopOnQueue() { pending?.cancel(); pending = nil; source?.setEventHandler {}; source?.cancel(); source = nil; seen.removeAll() }
}
