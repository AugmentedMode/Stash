import Foundation
import AppKit

public struct History: Codable {
    public var clips: [Clip] = []
    public init(clips: [Clip] = []) { self.clips = clips }
    public mutating func insert(_ clip: Clip, limit: Int = 500, maximumBytes: Int = 200 * 1024 * 1024) {
        // A clipboard-only capture can arrive without a screenshot marker. Merge
        // matching image pixels when the file watcher identifies that same capture.
        if clip.kind == .screenshot || clip.kind == .image,
            let data = clip.items.first?[NSPasteboard.PasteboardType.png.rawValue]
                ?? clip.items.first?[NSPasteboard.PasteboardType.tiff.rawValue]
        {
            let candidates = clips.indices.filter {
                (clips[$0].kind == .screenshot || clips[$0].kind == .image) && clips[$0].kind != clip.kind
                    && abs(clips[$0].createdAt.timeIntervalSince(clip.createdAt)) < 15
            }
            if !candidates.isEmpty, let normalized = ScreenshotCapture.clip(data: data),
                let index = candidates.first(where: { index in
                    guard
                        let other = clips[index].items.first?[NSPasteboard.PasteboardType.png.rawValue]
                            ?? clips[index].items.first?[NSPasteboard.PasteboardType.tiff.rawValue]
                    else { return false }
                    return ScreenshotCapture.clip(data: other)?.fingerprint == normalized.fingerprint
                })
            {
                let existing = clips.remove(at: index)
                let merged = Clip(
                    id: existing.id, createdAt: max(existing.createdAt, clip.createdAt),
                    sourceName: "Screenshot", sourceBundle: "com.apple.screencapture", kind: .screenshot,
                    text: normalized.text, pinned: existing.pinned || clip.pinned, items: normalized.items,
                    customTitle: existing.customTitle ?? clip.customTitle)
                insert(merged, limit: limit, maximumBytes: maximumBytes)
                return
            }
        }
        let fingerprint = clip.fingerprint
        if let index = clips.firstIndex(where: { $0.fingerprint == fingerprint }) {
            var existing = clips.remove(at: index)
            existing.createdAt = clip.createdAt
            existing.sourceName = clip.sourceName

            existing.sourceBundle = clip.sourceBundle
            existing.sourceTitle = clip.sourceTitle
            existing.sourceURL = clip.sourceURL
            clips.insert(existing, at: 0)
        } else {
            clips.insert(clip, at: 0)
        }
        enforceLimits(count: limit, bytes: maximumBytes)
    }

    /// Preserve the newest unpinned prefix and every pin in one pass. Pins do
    /// not consume either budget, even if their payload exceeds the byte limit.
    public mutating func enforceLimits(count: Int = 500, bytes: Int = 200 * 1024 * 1024) {
        var remainingCount = max(0, count)
        var remainingBytes = max(0, bytes)
        var exhausted = false
        clips = clips.filter { clip in
            if clip.pinned { return true }
            let size = clip.byteCount
            guard !exhausted, remainingCount > 0, size <= remainingBytes else {
                exhausted = true
                return false
            }
            remainingCount -= 1
            remainingBytes -= size
            return true
        }
    }

    public mutating func expire(days: Int, now: Date = Date()) {
        guard days > 0 else { return }
        let cutoff = now.addingTimeInterval(-Double(days) * 86400)

        clips.removeAll { !$0.pinned && $0.createdAt < cutoff }
    }
    public func filtered(query: String, kind: ClipKind? = nil, pinnedOnly: Bool = false) -> [Clip] {
        let search = SearchQuery(query)
        return clips.filter {
            (kind == nil || $0.kind == kind) && (!pinnedOnly || $0.pinned) && $0.matches(search)
        }.sorted {
            if $0.pinned != $1.pinned { return $0.pinned }
            return $0.createdAt > $1.createdAt
        }
    }
}
