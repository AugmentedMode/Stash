import SwiftUI
import AppKit
import StashCore

/// Small, quiet glyphs for the history list; illustrations belong in empty states.
struct ClipTypeIcon: View {
    let kind: ClipKind
    var textStyle: TextClipStyle? = nil

    var body: some View {
        Image(systemName: textStyle?.symbol ?? kind.symbol)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(kind == .email ? Color(red: 0.85, green: 0.65, blue: 0.97) : Color.muted)
            .frame(width: 30, height: 30)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

struct ThumbnailBadge: View {
    var symbol: String? = nil
    var count: Int? = nil

    var body: some View {
        Group {
            if let count { Text(count > 99 ? "99+" : String(count)) }
            else if let symbol { Image(systemName: symbol) }
        }
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 3).frame(minWidth: 13, minHeight: 13)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

/// Bundled and vector marks stay identical on machines without the service apps.
struct LinkIcon: View {
    let service: LinkPresentation.Service
    private static let bundled: [LinkPresentation.Service: NSImage] = {
        var images: [LinkPresentation.Service: NSImage] = [:]
        for service in LinkPresentation.Service.allCases {
            let url = Bundle.main.url(forResource: service.rawValue, withExtension: "png", subdirectory: "ServiceIcons")
                ?? Bundle.module.url(forResource: service.rawValue, withExtension: "png", subdirectory: "ServiceIcons")
            if let url, let image = NSImage(contentsOf: url) { images[service] = image }
        }
        return images
    }()

    var body: some View {
        Group {
            switch service {
            case .notion, .github, .chatgpt, .claude, .gemini, .perplexity,
                 .slack, .linear, .jira, .drive, .dropbox, .onedrive, .youtube, .loom,
                 .zoom, .meet, .teams, .cursor, .codex, .copilot, .grok:
                if let image = Self.bundled[service] {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else {
                    Image(systemName: "link").font(.system(size: 18)).foregroundStyle(Color.muted)
                }
            case .figma:
                FigmaMark().frame(width: 18, height: 27)
            case .docs, .sheets, .slides:
                GoogleDocumentMark(service: service).frame(width: 22, height: 28)
            case .web:
                Image(systemName: "globe").font(.system(size: 21, weight: .regular))
                    .foregroundStyle(Color.muted)
            }
        }.frame(width: 30, height: 30).accessibilityHidden(true)
    }
}

private struct FigmaMark: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5).fill(Color(red: 0.95, green: 0.31, blue: 0.12))
                UnevenRoundedRectangle(bottomTrailingRadius: 5, topTrailingRadius: 5).fill(Color(red: 1, green: 0.45, blue: 0.38))
            }
            HStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5).fill(Color(red: 0.64, green: 0.35, blue: 1))
                Circle().fill(Color(red: 0.10, green: 0.74, blue: 1))
            }
            HStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5, bottomTrailingRadius: 5).fill(Color(red: 0.04, green: 0.81, blue: 0.51))
                Color.clear
            }
        }
    }
}

private struct GoogleDocumentMark: View {
    let service: LinkPresentation.Service
    private var tint: Color {
        switch service {
        case .sheets: return Color(red: 0.06, green: 0.62, blue: 0.35)
        case .slides: return Color(red: 0.96, green: 0.71, blue: 0)
        default: return Color(red: 0.26, green: 0.52, blue: 0.96)
        }
    }

    var body: some View {
        ZStack {
            Path { p in
                p.move(to: .zero); p.addLine(to: CGPoint(x: 15, y: 0))
                p.addLine(to: CGPoint(x: 22, y: 7)); p.addLine(to: CGPoint(x: 22, y: 28))
                p.addLine(to: CGPoint(x: 0, y: 28)); p.closeSubpath()
            }.fill(tint)
            Path { p in
                p.move(to: CGPoint(x: 15, y: 0)); p.addLine(to: CGPoint(x: 15, y: 7))
                p.addLine(to: CGPoint(x: 22, y: 7)); p.closeSubpath()
            }.fill(.white.opacity(0.35))
            Group {
                switch service {
                case .sheets:
                    Image(systemName: "tablecells").font(.system(size: 13, weight: .semibold))
                case .slides:
                    Image(systemName: "rectangle.fill").font(.system(size: 12))
                default:
                    Image(systemName: "text.alignleft").font(.system(size: 12, weight: .semibold))
                }
            }.foregroundStyle(.white).offset(y: 4)
        }.clipShape(RoundedRectangle(cornerRadius: 2))
    }
}
