import AppKit
import SwiftUI
import ImageIO
import StashCore

struct HighlightedText: View {
    let value: String
    let query: String
    private var highlighted: AttributedString {
        var result = AttributedString(value)
        for range in SearchHighlight.ranges(in: value, query: query) {
            if let lower = AttributedString.Index(range.lowerBound, within: result),
                let upper = AttributedString.Index(range.upperBound, within: result)
            {
                result[lower..<upper].foregroundColor = Color.accent
                result[lower..<upper].backgroundColor = Color.accent.opacity(0.13)
            }
        }
        return result
    }
    var body: some View { Text(highlighted) }
}
