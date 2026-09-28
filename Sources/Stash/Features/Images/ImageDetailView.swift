import AppKit
import SwiftUI
import ImageIO
import StashCore

/// Keeps the entire image visible at Fit; zoomed images scroll inside the same viewport.
struct ImageDetailView: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    let imageNamespace: Namespace.ID
    @State private var image: NSImage?
    @State private var zoomed = false
    @State private var loading = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(clip.displayTitle).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                Button(zoomed ? "Fit" : "Zoom in") { toggleZoom() }
                    .buttonStyle(.plain).foregroundStyle(Color.accent)
                    .disabled(image == nil).accessibilityLabel(zoomed ? "Fit image" : "Zoom image")
                Button {
                    model.togglePin(clip)
                } label: {
                    PinGlyph(pinned: clip.pinned)
                }
                .buttonStyle(.plain).accessibilityLabel(clip.pinned ? "Unpin clip" : "Pin clip")
                Button {
                    model.openActions(for: clip)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain).accessibilityLabel("Clip actions")
            }
            GeometryReader { geometry in
                if let image {
                    let scale = min(
                        geometry.size.width / max(1, image.size.width),
                        geometry.size.height / max(1, image.size.height))
                    let width = image.size.width * scale * (zoomed ? 2.5 : 1)
                    let height = image.size.height * scale * (zoomed ? 2.5 : 1)
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: image).resizable().interpolation(.high)
                            .frame(width: width, height: height)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture { toggleZoom() }
                            .accessibilityLabel(clip.displayTitle)
                            .accessibilityAction(named: zoomed ? "Fit image" : "Zoom image") { toggleZoom() }
                    }
                    .help(zoomed ? "Click to fit · Scroll to explore" : "Click to zoom")
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Image preview unavailable").foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .matchedGeometryEffect(id: clip.id, in: imageNamespace, isSource: false)
            HStack(spacing: 5) {
                SourceAppIcon(clip: clip)
                Text(clip.sourceName).lineLimit(1)
                Spacer()
                Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                Text("·")
                Text(ByteCountFormatter.string(fromByteCount: Int64(clip.byteCount), countStyle: .file))
            }.font(.system(size: 10)).foregroundStyle(Color.quiet)
        }.padding(18)
            .task(id: clip.fingerprint) {
                loading = true
                zoomed = false
                image = PreviewCache.cached(clip)
                let loaded = await PreviewCache.load(clip, pixels: 2000)
                if !Task.isCancelled {
                    image = loaded
                    loading = false
                }
            }
    }
    private func toggleZoom() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { zoomed.toggle() }
    }
}
