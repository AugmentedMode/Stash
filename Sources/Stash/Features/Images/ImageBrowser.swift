import AppKit
import SwiftUI
import ImageIO
import StashCore

struct ImageBrowser: View {
    @ObservedObject var model: AppModel
    let imageNamespace: Namespace.ID
    var body: some View {
        GeometryReader { geometry in
            let selectedID = model.selected?.id
            let browserWidth = max(220, geometry.size.width * 0.46)
            let columns = max(2, Int((browserWidth - 28) / 112))
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
                            spacing: 8
                        ) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, clip in
                                tile(clip, index: index, selected: selectedID == clip.id).id(clip.id)
                            }
                        }.padding(12)
                    }
                    .onChange(of: model.selection) { _, id in if let id { proxy.scrollTo(id) } }
                    .onChange(of: model.query) { _, _ in
                        if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                    .onChange(of: model.category) { _, _ in
                        if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                }.frame(width: browserWidth)
                Rectangle().fill(Color.line).frame(width: 0.5)
                if let clip = model.selected {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            model.previewOpen = true
                        } label: {
                            ClipImage(clip: clip, pixels: 1200)
                                .matchedGeometryEffect(id: clip.id, in: imageNamespace)
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).help("Expand preview · Space").accessibilityLabel(
                            "Expand selected image")
                        VStack(alignment: .leading, spacing: 6) {
                            HighlightedText(value: clip.displayTitle, query: model.query).font(
                                .system(size: 13, weight: .medium)
                            ).lineLimit(2)
                            HStack(spacing: 5) {
                                SourceAppIcon(clip: clip)
                                HighlightedText(value: clip.sourceName, query: model.query)
                                Spacer(minLength: 0)
                                if clip.pinned { PinGlyph(pinned: true) }
                            }.font(.system(size: 11)).foregroundStyle(Color.quiet)
                            Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened)).font(
                                .system(size: 10)
                            ).foregroundStyle(Color.quiet)
                        }
                        HStack {
                            Text("Space to expand").font(.system(size: 10)).foregroundStyle(Color.quiet)
                            Spacer()
                            Button {
                                model.openActions()
                            } label: {
                                Label("Actions", systemImage: "ellipsis")
                            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color.accent)
                        }
                    }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    private func tile(_ clip: Clip, index: Int, selected: Bool) -> some View {
        return VStack(alignment: .leading, spacing: 7) {
            ClipImage(clip: clip).frame(height: 78)
                .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 3) {
                HighlightedText(value: clip.displayTitle, query: model.query).lineLimit(1)
                Spacer(minLength: 0)
                if clip.pinned { PinGlyph(pinned: true) }
            }.font(.system(size: 10, weight: .medium))
        }.padding(7)
            .background(
                selected ? Color.accent.opacity(0.14) : .white.opacity(0.025),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10).strokeBorder(
                    selected ? Color.accent.opacity(0.6) : Color.line, lineWidth: selected ? 1 : 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                model.selection = clip.id
                model.previewOpen = true
            }
            .onTapGesture {
                model.selection = clip.id

                NotificationCenter.default.post(name: .stashFocusResults, object: nil)
            }
            .contextMenu { ClipActionButtons(model: model, clip: clip) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(clip.displayTitle), \(clip.sourceName), \(index + 1) of \(model.results.count)"
            )
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
            .accessibilityAction { model.selection = clip.id }
            .accessibilityAction(named: "Preview") {
                model.selection = clip.id
                model.previewOpen = true
            }
    }
}
