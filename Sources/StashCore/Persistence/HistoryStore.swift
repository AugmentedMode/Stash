import Foundation

/// Clipboard history on disk as a small index plus one payload file per clip.
///
/// The index holds each clip's details and text. Pasteboard data (images, rich text,
/// file references) lives in `payloads/`, written once when a clip first appears and
/// deleted when it leaves history. A save after one copy therefore writes the index
/// and at most one new payload, instead of re-encoding every image in history.
///
/// `save` runs on the history writer's queue; `load` runs once before any save.
public final class HistoryStore {
    public let directory: URL
    /// The single-file `history.json` used before this format. Migrated, then removed.
    public let legacyURL: URL?
    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private var payloadDirectory: URL { directory.appendingPathComponent("payloads") }
    private let lock = NSLock()
    /// Payload file name → size in bytes, for files known to be on disk.
    private var payloads: [String: Int64]?
    private var indexBytes: Int64 = 0

    private struct Index: Codable {
        var version = 1
        var clips: [Clip]
    }

    public init(directory: URL, legacyURL: URL? = nil) {
        self.directory = directory
        self.legacyURL = legacyURL
    }

    /// Total bytes used by the index and payloads, as of the last load or save.
    public var bytesOnDisk: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return indexBytes + (payloads?.values.reduce(0, +) ?? 0)
    }

    public func load() throws -> History {
        let manager = FileManager.default
        guard manager.fileExists(atPath: indexURL.path) else {
            guard let legacyURL, manager.fileExists(atPath: legacyURL.path) else { return History() }
            let history = try HistoryDisk.load(from: legacyURL)
            // Keep the old file until the new format is safely written.
            try save(history)
            try? manager.removeItem(at: legacyURL)
            return history
        }
        let data = try Data(contentsOf: indexURL)
        let index = try JSONDecoder().decode(Index.self, from: data)
        let onDisk = scanPayloads()
        var clips: [Clip] = []
        clips.reserveCapacity(index.clips.count)
        for clip in index.clips {
            let name = Self.payloadName(for: clip)
            if onDisk[name] != nil,
                let payload = try? Data(contentsOf: payloadDirectory.appendingPathComponent(name)),
                let items = try? PropertyListDecoder().decode([[String: Data]].self, from: payload)
            {
                clips.append(clip.withItems(items))
            } else if !clip.kind.needsPayload {
                // Text still pastes from the index if its rich formatting was lost.
                clips.append(clip)
            }
        }
        lock.lock()
        payloads = onDisk
        indexBytes = Int64(data.count)
        lock.unlock()
        return History(clips: clips)
    }

    public func save(_ history: History) throws {
        let manager = FileManager.default
        try Self.createPrivateDirectory(directory)
        try Self.createPrivateDirectory(payloadDirectory)
        var known = currentPayloads()
        var referenced = Set<String>()
        // Payloads first, then the index, so the index never names a missing file.
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        for clip in history.clips where !clip.items.isEmpty {
            let name = Self.payloadName(for: clip)
            referenced.insert(name)
            guard known[name] == nil else { continue }
            let data = try encoder.encode(clip.items)
            try Self.writePrivate(data, to: payloadDirectory.appendingPathComponent(name))
            known[name] = Int64(data.count)
        }
        let index = try JSONEncoder().encode(Index(clips: history.clips.map { $0.withItems([]) }))
        try Self.writePrivate(index, to: indexURL)
        for name in known.keys where !referenced.contains(name) {
            try? manager.removeItem(at: payloadDirectory.appendingPathComponent(name))
            known[name] = nil
        }
        lock.lock()
        payloads = known
        indexBytes = Int64(index.count)
        lock.unlock()
    }

    /// Includes the fingerprint so a clip whose payload changes gets a new file.
    static func payloadName(for clip: Clip) -> String {
        "\(clip.id.uuidString)-\(clip.fingerprint.prefix(16)).plist"
    }

    private func currentPayloads() -> [String: Int64] {
        lock.lock()
        let cached = payloads
        lock.unlock()
        return cached ?? scanPayloads()
    }

    private func scanPayloads() -> [String: Int64] {
        let keys: [URLResourceKey] = [.fileSizeKey]
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: payloadDirectory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
        var result: [String: Int64] = [:]
        for file in files where file.pathExtension == "plist" {
            result[file.lastPathComponent] = Int64(
                (try? file.resourceValues(forKeys: Set(keys)).fileSize) ?? 0)
        }
        return result
    }

    static func createPrivateDirectory(_ url: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    static func writePrivate(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

extension ClipKind {
    /// Kinds that are meaningless without their pasteboard payload.
    var needsPayload: Bool { [.image, .screenshot, .file, .video].contains(self) }
}
