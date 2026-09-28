import SwiftUI
import AppKit
import ApplicationServices
import StashCore

struct Glyph: View {
    let kind: ClipKind
    var large = false
    var tint: Color {
        switch kind {
        case .text: return .muted

        case .link: return Color(red: 0.56, green: 0.73, blue: 0.99)

        case .email: return Color(red: 0.85, green: 0.65, blue: 0.97)

        case .color: return .accent

        case .image, .screenshot: return .orange

        case .video: return .pink

        case .file: return .cyan
        }
    }
    var body: some View {
        Image(systemName: kind.symbol).font(.system(size: large ? 24 : 16, weight: .medium)).foregroundStyle(
            tint
        ).frame(width: large ? 56 : 36, height: large ? 56 : 36).background(
            tint.opacity(0.09), in: RoundedRectangle(cornerRadius: large ? 14 : 10))
    }
}
