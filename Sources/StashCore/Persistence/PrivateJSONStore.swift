import Foundation

/// Shared local-file policy for clipboard history and explicitly saved prompts.
/// Callers decide whether a failed load permits future writes.
enum PrivateJSONStore {
    static func load<Value: Decodable>(from url: URL, default fallback: @autoclosure () -> Value) throws
        -> Value
    {
        do {
            return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return fallback()
        }
    }

    static func save<Value: Encodable>(_ value: Value, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        // Also repair permissions on an existing application-data directory.
        // This keeps the atomic temporary file private before it is renamed.
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try data.write(to: url, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
