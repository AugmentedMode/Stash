import Foundation

public struct SavedPrompt: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var body: String

    public init(id: UUID = UUID(), name: String = "", body: String = "") {
        self.id = id
        self.name = name
        self.body = body
    }

    private static let fieldPattern = try! NSRegularExpression(
        pattern: #"\{\{([A-Za-z][A-Za-z0-9_ -]{0,39})\}\}"#)
    private var matches: [NSTextCheckingResult] {
        Self.fieldPattern.matches(in: body, range: NSRange(body.startIndex..., in: body))
    }
    public var fields: [String] {
        var result: [String] = []
        var seen = Set<String>()
        for match in matches {
            let name = (body as NSString).substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespaces)
            if seen.insert(name).inserted { result.append(name) }
        }
        return result
    }
    public func rendered(values: [String: String]) -> String? {
        guard
            fields.allSatisfy({ !(values[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { return nil }
        return preview(values: values)
    }
    /// Substitute filled fields while keeping unfilled placeholders visible.
    public func preview(values: [String: String]) -> String {
        let result = NSMutableString(string: body)
        for match in matches.reversed() {
            let key = (body as NSString).substring(with: match.range(at: 1)).trimmingCharacters(
                in: .whitespaces)
            if let value = values[key], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.replaceCharacters(in: match.range, with: value)
            }
        }
        return result as String
    }
    public func matches(_ query: String) -> Bool {
        matches(SearchQuery(query))
    }
    public func matches(_ query: SearchQuery) -> Bool {
        query.isEmpty || query.matches(name + " " + body)
    }

    public static let maximumNameLength = 100
    public static let maximumBodyBytes = 65_536

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.count <= Self.maximumNameLength && body.utf8.count <= Self.maximumBodyBytes
    }
}
