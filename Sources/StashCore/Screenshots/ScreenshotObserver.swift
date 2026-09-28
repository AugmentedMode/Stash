import AppKit
import Darwin

/// Watches one directory; metadata reads and image decoding run on a utility queue.
/// Stop/restart invalidates pending scans and already-enqueued main-thread deliveries.
public final class ScreenshotObserver {
    private let queue = DispatchQueue(label: "app.stash.screenshots", qos: .utility)
    private let deliveryLock = NSLock()
    private var deliveryGeneration = UUID()
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var scanGeneration = UUID()
    private var seen = Set<URL>()
    private var began = Date()
    private static let retryDelay: TimeInterval = 0.4
    private static let maximumAttempt = 4

    public init() {}

    deinit {
        pending?.cancel()
        source?.setEventHandler {}
        source?.cancel()
    }

    public func start(folder: URL, receive: @escaping (Clip) -> Void, failure: @escaping () -> Void) {
        let delivery = invalidateDeliveries()
        queue.async { [self] in
            stopOnQueue()
            let descriptor = open(folder.path, O_EVTONLY)
            guard descriptor >= 0,
                let urls = try? FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: nil)
            else {
                if descriptor >= 0 { close(descriptor) }
                deliver(generation: delivery, failure)
                return
            }
            seen = Set(urls)
            began = Date()
            let watch = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor, eventMask: [.write, .rename, .delete, .revoke], queue: queue)
            watch.setCancelHandler { close(descriptor) }
            // Read the owned source rather than capturing watch in its own handler.
            watch.setEventHandler { [weak self] in
                guard let self, let source = self.source else { return }
                if !source.data.intersection([.rename, .delete, .revoke]).isEmpty {
                    self.stopOnQueue()
                    self.deliver(generation: delivery, failure)
                    return
                }
                self.schedule(
                    folder: folder, attempt: 0, delivery: delivery, receive: receive, failure: failure)
            }
            source = watch
            watch.resume()
        }
    }

    private func schedule(
        folder: URL, attempt: Int, delivery: UUID,
        receive: @escaping (Clip) -> Void, failure: @escaping () -> Void
    ) {
        pending?.cancel()
        let token = UUID()
        scanGeneration = token
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.source != nil, self.scanGeneration == token else { return }
            self.pending = nil
            let urls: [URL]
            do {
                urls = try FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: [.creationDateKey])
            } catch {
                self.stopOnQueue()
                self.deliver(generation: delivery, failure)
                return
            }
            self.seen.formIntersection(Set(urls))
            // Read dates once and sort only unseen entries, not the whole Desktop.
            var candidates: [(url: URL, date: Date)] = []
            var retryNeeded = false
            for url in urls where !self.seen.contains(url) {
                guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                    if attempt < Self.maximumAttempt { retryNeeded = true } else { self.seen.insert(url) }
                    continue
                }
                guard date >= self.began else {
                    self.seen.insert(url)
                    continue
                }
                candidates.append((url, date))
            }
            candidates.sort { $0.date < $1.date }
            for candidate in candidates {
                if let clip = ScreenshotCapture.load(candidate.url) {
                    self.seen.insert(candidate.url)
                    self.deliver(generation: delivery) { receive(clip) }
                } else if attempt < Self.maximumAttempt {
                    // Files and screenshot metadata can arrive in separate writes.
                    retryNeeded = true
                } else {
                    self.seen.insert(candidate.url)
                }
            }
            if retryNeeded {
                self.schedule(
                    folder: folder, attempt: attempt + 1, delivery: delivery,
                    receive: receive, failure: failure)
            }
        }
        pending = work
        queue.asyncAfter(deadline: .now() + Self.retryDelay, execute: work)
    }

    public func stop() {
        _ = invalidateDeliveries()
        queue.async { [self] in stopOnQueue() }
    }

    private func stopOnQueue() {
        scanGeneration = UUID()
        pending?.cancel()
        pending = nil
        source?.setEventHandler {}
        source?.cancel()
        source = nil
        seen.removeAll()
    }

    private func invalidateDeliveries() -> UUID {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        deliveryGeneration = UUID()
        return deliveryGeneration
    }

    private func deliver(generation: UUID, _ action: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.deliveryLock.lock()
            let isCurrent = self.deliveryGeneration == generation
            self.deliveryLock.unlock()
            if isCurrent { action() }
        }
    }
}
