import Foundation

/// Tokenize once per search, then reuse across clips or saved prompts.
public struct SearchQuery {
    private let terms: [String]

    public init(_ query: String) {
        terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    public var isEmpty: Bool { terms.isEmpty }

    public func matches(_ text: String) -> Bool {
        terms.allSatisfy { text.localizedStandardContains($0) }
    }
}
