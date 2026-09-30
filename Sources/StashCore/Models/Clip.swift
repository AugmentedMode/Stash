import Foundation
import AppKit
import CryptoKit

public struct Clip: Codable, Identifiable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var sourceName: String
    public var sourceBundle: String
    /// Focused window title at copy time, such as a Slack channel or Terminal tab.
    public var sourceTitle: String?
    /// Page the copy came from, when a browser reports one.
    public var sourceURL: String?
    public let kind: ClipKind
    public let text: String
    public var customTitle: String?
    public var pinned: Bool
    public let items: [[String: Data]]
    public let fingerprint: String
    public init(
        id: UUID = UUID(), createdAt: Date = Date(), sourceName: String, sourceBundle: String = "",
        kind: ClipKind, text: String, pinned: Bool = false, items: [[String: Data]] = [],
        customTitle: String? = nil, sourceTitle: String? = nil, sourceURL: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceName = sourceName

        self.sourceBundle = sourceBundle
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.kind = kind
        self.text = text
        self.pinned = pinned

        self.items = items
        self.customTitle = customTitle
        self.fingerprint = Self.makeFingerprint(kind: kind, text: text, items: items)
    }
    public var title: String {
        text.split(maxSplits: 1, whereSeparator: \.isNewline).first.map(String.init) ?? kind.title
    }
    public var sourceHost: String? {
        guard let sourceURL, let host = URL(string: sourceURL)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    /// The most specific place the copy came from, for the row's details line.
    public var sourceContext: String? {
        if let sourceTitle, !sourceTitle.isEmpty { return sourceTitle }
        return sourceHost
    }
    public var byteCount: Int { items.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } }
    private static func makeFingerprint(kind: ClipKind, text: String, items: [[String: Data]]) -> String {
        var hash = SHA256()
        hash.update(data: Data(kind.rawValue.utf8))
        hash.update(data: Data(text.utf8))
        for item in items {
            hash.update(data: Data([0]))

            for key in item.keys.sorted() {
                hash.update(data: Data(key.utf8))
                hash.update(data: item[key]!)
            }
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public var image: NSImage? {
        for item in items {
            for key in [NSPasteboard.PasteboardType.png.rawValue, NSPasteboard.PasteboardType.tiff.rawValue] {
                if let data = item[key], let image = NSImage(data: data) { return image }
            }
        }
        return nil
    }
    public var fileURLs: [URL] {
        items.compactMap { item in
            guard let data = item[NSPasteboard.PasteboardType.fileURL.rawValue],
                let s = String(data: data, encoding: .utf8)
            else { return nil }
            return URL(string: s)
        }
    }
    public func matches(_ query: String) -> Bool {
        matches(SearchQuery(query))
    }
    public func matches(_ query: SearchQuery) -> Bool {
        guard !query.isEmpty else { return true }
        let searchable =
            (customTitle ?? "") + " " + text + " " + sourceName + " " + (sourceTitle ?? "") + " "
            + (sourceURL ?? "") + " " + kind.title + " "
            + (linkPresentation.map { $0.title + " " + $0.label } ?? "")
        return query.matches(searchable)
    }
}
