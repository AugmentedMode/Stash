import SwiftUI
import AppKit

struct PinGlyph: View {
    let pinned: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var glyph: some View {
        Image(systemName: pinned ? "pin.fill" : "pin")
            .foregroundStyle(pinned ? Color.accent : Color.quiet)
    }

    var body: some View {
        Group {
            if reduceMotion {
                glyph
            } else {
                glyph.symbolEffect(.bounce, options: .nonRepeating, value: pinned)
            }
        }.accessibilityHidden(true)
    }
}

/// SVG masters live in Assets/CategoryArt; matching PDF vectors render natively.
enum CategoryArtwork: String, CaseIterable {
    case all, pinned, text, link, image, screenshot, file, video, email, color, search

    private static let images: [Self: NSImage] = {
        var images: [Self: NSImage] = [:]
        for kind in allCases {
            let url =
                Bundle.main.url(forResource: kind.rawValue, withExtension: "pdf", subdirectory: "CategoryArt")
                ?? Bundle.module.url(
                    forResource: kind.rawValue, withExtension: "pdf", subdirectory: "CategoryArt")
            if let url, let image = NSImage(contentsOf: url) { images[kind] = image }
        }
        return images
    }()

    var image: NSImage? { Self.images[self] }
}

struct CategoryIllustration: View {
    var artwork: CategoryArtwork = .all
    var compact = false
    var animateEntrance = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        Group {
            if let image = artwork.image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "square.stack.3d.up").foregroundStyle(Color.accent)
            }
        }
        .frame(width: compact ? 38 : 160, height: compact ? 30 : 120)
        .scaleEffect(compact || !animateEntrance || settled ? 1 : 0.94)
        .offset(y: compact || !animateEntrance || settled ? 0 : 5)
        .accessibilityHidden(true)
        .onAppear {
            guard animateEntrance, !compact, !settled else { return }
            withAnimation(reduceMotion || compact ? nil : .spring(duration: 0.4, bounce: 0.15)) {
                settled = true
            }
        }
    }
}
