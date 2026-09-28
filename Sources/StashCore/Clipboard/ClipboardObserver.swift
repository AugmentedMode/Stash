import AppKit

/// Reads only changed pasteboards, and advances past paused or excluded copies.
/// A named board can be injected for integration checks without touching a user's clipboard.
public final class ClipboardObserver {
    public let board: NSPasteboard
    private var lastChange: Int
    public init(board: NSPasteboard = .general) {
        self.board = board
        lastChange = board.changeCount
    }
    public var hasChanges: Bool { board.changeCount != lastChange }
    public func skipCurrentChange() { lastChange = board.changeCount }
    public func read(
        sourceName: String, sourceBundle: String, excluded: Set<String> = ClipboardCodec.defaultExclusions,
        paused: Bool = false
    ) -> Clip? {
        guard board.changeCount != lastChange else { return nil }
        lastChange = board.changeCount
        guard !paused else { return nil }
        return ClipboardCodec.capture(
            board, sourceName: sourceName, sourceBundle: sourceBundle, excluded: excluded)
    }
}
