import Foundation

public enum HistoryDisk {
    public static func load(from url: URL) throws -> History {
        try PrivateJSONStore.load(from: url, default: History())
    }

    public static func save(_ history: History, to url: URL) throws {
        try PrivateJSONStore.save(history, to: url)
    }
}
