import SwiftUI
import AppKit
import ApplicationServices
import StashCore

struct PaletteRow: View {
    let clip: Clip
    let index: Int
    let query: String
    let imageNamespace: Namespace.ID
    let selected: Bool
    var onSelect: () -> Void
    var onPaste: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 13) {
            thumbnail.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                HighlightedText(value: clip.displayTitle, query: query).font(
                    .system(size: 14, weight: .medium)
                ).foregroundStyle(.white.opacity(selected ? 1 : 0.9)).lineLimit(1)
                HStack(spacing: 5) {
                    SourceAppIcon(clip: clip)
                    HighlightedText(value: clip.sourceName, query: query)
                    if let link = clip.linkPresentation {
                        Text("·")
                        HighlightedText(value: link.host, query: query)
                    }
                    Text("·").opacity(0.7)
                    Text(clip.createdAt.formatted(date: .omitted, time: .shortened))
                    PinGlyph(pinned: clip.pinned).font(.system(size: 9)).opacity(clip.pinned ? 1 : 0).padding(
                        .leading, 2)
                }.font(.system(size: 11)).foregroundStyle(Color.quiet).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button(action: onPaste) {
                Text(hovering || selected ? "↵" : index < 9 ? "⌘\(index + 1)" : "")
                    .font(.system(size: 11, weight: .regular)).foregroundStyle(
                        selected ? Color.white.opacity(0.65) : Color.muted.opacity(0.65)
                    )
                    .frame(width: 31, height: 29)
                    .background(
                        hovering ? .white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain).help("Paste this clip").accessibilityLabel("Paste \(clip.displayTitle)")
        }.padding(.horizontal, 15).padding(.vertical, 10)
            .background(
                selected ? Color.accent.opacity(0.13) : hovering ? .white.opacity(0.045) : .clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    selected ? Color.accent.opacity(0.14) : .clear, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onPaste)
            .onHover { hovering = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(clip.displayTitle)
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityAction(named: "Select", onSelect)
    }
    @ViewBuilder var thumbnail: some View {
        if let link = clip.linkPresentation {
            LinkIcon(service: link.service)
        } else if let service = clip.aiSourceService {
            LinkIcon(service: service)
        } else if clip.kind == .color {
            RoundedRectangle(cornerRadius: 8).fill(Color.hex(clip.text)).padding(2).overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.10)).padding(2))
        } else if clip.isVisual {
            ClipImage(clip: clip).frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 6))
                .matchedGeometryEffect(id: clip.id, in: imageNamespace)
                .overlay(alignment: .bottomTrailing) {
                    if clip.kind == .screenshot { ThumbnailBadge(symbol: "viewfinder") }
                }
        } else if let file = clip.fileURLs.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().scaledToFit()
                .padding(1)
                .overlay(alignment: .bottomTrailing) {
                    if clip.fileURLs.count > 1 {
                        ThumbnailBadge(count: clip.fileURLs.count)
                    } else if clip.kind == .video {
                        ThumbnailBadge(symbol: "play.fill")
                    }
                }
        } else {
            ClipTypeIcon(kind: clip.kind, textStyle: clip.textStyle)
        }
    }
}
