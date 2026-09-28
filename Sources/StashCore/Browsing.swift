import Foundation

public enum SearchHighlight {
    public static func ranges(in text: String, query: String) -> [Range<String.Index>] {
        var matches: [Range<String.Index>] = []
        for term in query.split(whereSeparator: \.isWhitespace) {
            var start = text.startIndex
            while start < text.endIndex,
                  let range = text.range(of: String(term), options: [.caseInsensitive, .diacriticInsensitive], range: start..<text.endIndex, locale: .current) {
                guard range.upperBound > start else { break }
                matches.append(range)
                start = range.upperBound
            }
        }
        return matches
    }
}

public extension Clip {
    var isVisual: Bool { kind == .image || kind == .screenshot }
}
