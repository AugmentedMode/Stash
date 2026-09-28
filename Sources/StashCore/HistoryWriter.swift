import Foundation

/// Coalesces bursts without delaying a save indefinitely. Only the latest snapshot
/// is retained while waiting; encoding and disk I/O run on a utility queue.
public final class HistoryWriter {
    private let queue = DispatchQueue(label: "app.stash.history", qos: .utility)
    private let lock = NSLock()
    private let delay: TimeInterval
    private let write: (History) throws -> Void
    private let onError: (Error) -> Void
    private var latest: History?
    private var pending: DispatchWorkItem?
    private var generation: UUID?

    public init(delay: TimeInterval = 1, write: @escaping (History) throws -> Void, onError: @escaping (Error) -> Void = { _ in }) {
        self.delay = delay; self.write = write; self.onError = onError
    }
    public func submit(_ history: History, immediately: Bool = false) {
        lock.lock()
        latest = history
        if immediately { pending?.cancel(); pending = nil; generation = nil }
        if pending == nil {
            let token = UUID()
            generation = token
            let item = DispatchWorkItem { [weak self] in self?.commit(token) }
            pending = item
            queue.asyncAfter(deadline: .now() + (immediately ? 0 : delay), execute: item)
        }
        lock.unlock()
    }
    private func commit(_ token: UUID) {
        lock.lock()
        guard generation == token else { lock.unlock(); return }
        let snapshot = latest
        latest = nil; pending = nil; generation = nil
        lock.unlock()
        if let snapshot { persist(snapshot) }
    }
    private func persist(_ snapshot: History) {
        do { try write(snapshot) } catch { onError(error) }
    }
    /// Call from the owner thread, never from write/onError. Completes prior writes
    /// and the newest pending snapshot before quit or system sleep.
    public func flush() {
        lock.lock()
        pending?.cancel(); pending = nil; generation = nil
        let snapshot = latest; latest = nil
        lock.unlock()
        queue.sync { if let snapshot { persist(snapshot) } }
    }
}

public enum ClipboardPollingPolicy {
    public static func interval(paused: Bool, suspended: Bool, lowPower: Bool) -> TimeInterval? {
        guard !paused, !suspended else { return nil }
        return lowPower ? 1.2 : 0.6
    }
}
