import AppKit
import SwiftUI
import ImageIO
import StashCore

@MainActor
private enum PreviewCache {
    static let images: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()
    static func cached(_ clip: Clip) -> NSImage? {
        for pixels in [2000, 1200, 320] {
            if let image = images.object(forKey: "\(clip.fingerprint)-\(pixels)" as NSString) { return image }
        }
        return nil
    }
    static func load(_ clip: Clip, pixels: Int) async -> NSImage? {
        let key = "\(clip.fingerprint)-\(pixels)" as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let data = clip.items.lazy.compactMap({ $0[NSPasteboard.PasteboardType.png.rawValue] ?? $0[NSPasteboard.PasteboardType.tiff.rawValue] }).first else { return nil }
        let cgImage = await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil as CGImage? }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }.value
        guard !Task.isCancelled, let cgImage else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        images.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
}

struct ClipImage: View {
    let clip: Clip
    var pixels = 320
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            if let image { Image(nsImage: image).resizable().scaledToFit() }
            else { Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(Color.quiet) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: "\(clip.fingerprint)-\(pixels)") {
                image = PreviewCache.cached(clip)
                let loaded = await PreviewCache.load(clip, pixels: pixels)
                if !Task.isCancelled { image = loaded }
            }
    }
}

struct SourceAppIcon: View {
    let clip: Clip
    private static var icons: [String: NSImage] = [:]
    private static var missing: Set<String> = []
    private var icon: NSImage? {
        let id = clip.sourceBundle
        guard !id.isEmpty, !Self.missing.contains(id) else { return nil }
        if let image = Self.icons[id] { return image }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { Self.missing.insert(id); return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        Self.icons[id] = image
        return image
    }
    var body: some View {
        Group {
            if let icon { Image(nsImage: icon).resizable().scaledToFit() }
            else { Image(systemName: clip.kind == .screenshot ? "camera.viewfinder" : "app").resizable().scaledToFit().foregroundStyle(Color.quiet) }
        }.frame(width: 12, height: 12).accessibilityHidden(true)
    }
}

struct HighlightedText: View {
    let value: String
    let query: String
    private var highlighted: AttributedString {
        var result = AttributedString(value)
        for range in SearchHighlight.ranges(in: value, query: query) {
            if let lower = AttributedString.Index(range.lowerBound, within: result),
               let upper = AttributedString.Index(range.upperBound, within: result) {
                result[lower..<upper].foregroundColor = Color.accent
                result[lower..<upper].backgroundColor = Color.accent.opacity(0.13)
            }
        }
        return result
    }
    var body: some View { Text(highlighted) }
}

struct ImageBrowser: View {
    @ObservedObject var model: AppModel
    let imageNamespace: Namespace.ID
    var body: some View {
        GeometryReader { geometry in
            let browserWidth = max(220, geometry.size.width * 0.46)
            let columns = max(2, Int((browserWidth - 28) / 112))
            HStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, clip in
                                tile(clip, index: index).id(clip.id)
                            }
                        }.padding(12)
                    }
                    .onChange(of: model.selection) { _, id in if let id { proxy.scrollTo(id) } }
                    .onChange(of: model.query) { _, _ in if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) } }
                    .onChange(of: model.category) { _, _ in if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) } }
                }.frame(width: browserWidth)
                Rectangle().fill(Color.line).frame(width: 0.5)
                if let clip = model.selected {
                    VStack(alignment: .leading, spacing: 12) {
                        Button { model.previewOpen = true } label: {
                            ClipImage(clip: clip, pixels: 1200)
                                .matchedGeometryEffect(id: clip.id, in: imageNamespace)
                                .padding(8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).help("Expand preview · Space").accessibilityLabel("Expand selected image")
                        VStack(alignment: .leading, spacing: 6) {
                            HighlightedText(value: clip.displayTitle, query: model.query).font(.system(size: 13, weight: .medium)).lineLimit(2)
                            HStack(spacing: 5) {
                                SourceAppIcon(clip: clip)
                                HighlightedText(value: clip.sourceName, query: model.query)
                                Spacer(minLength: 0)
                                if clip.pinned { PinGlyph(pinned: true) }
                            }.font(.system(size: 11)).foregroundStyle(Color.quiet)
                            Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(Color.quiet)
                        }
                        HStack {
                            Text("Space to expand").font(.system(size: 10)).foregroundStyle(Color.quiet)
                            Spacer()
                            Button { model.openActions() } label: { Label("Actions", systemImage: "ellipsis") }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Color.accent)
                        }
                    }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    private func tile(_ clip: Clip, index: Int) -> some View {
        let selected = model.selected?.id == clip.id
        return VStack(alignment: .leading, spacing: 7) {
            ClipImage(clip: clip).frame(height: 78)
                .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 3) {
                HighlightedText(value: clip.displayTitle, query: model.query).lineLimit(1)
                Spacer(minLength: 0)
                if clip.pinned { PinGlyph(pinned: true) }
            }.font(.system(size: 10, weight: .medium))
        }.padding(7)
            .background(selected ? Color.accent.opacity(0.14) : .white.opacity(0.025), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accent.opacity(0.6) : Color.line, lineWidth: selected ? 1 : 0.5))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.selection = clip.id; model.previewOpen = true }
            .onTapGesture { model.selection = clip.id; NotificationCenter.default.post(name: .init("StashFocusResults"), object: nil) }
            .contextMenu { ClipActionButtons(model: model, clip: clip) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(clip.displayTitle), \(clip.sourceName), \(index + 1) of \(model.results.count)")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
            .accessibilityAction { model.selection = clip.id }
            .accessibilityAction(named: "Preview") { model.selection = clip.id; model.previewOpen = true }
    }
}

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
                Button { model.togglePin(clip) } label: { PinGlyph(pinned: clip.pinned) }
                    .buttonStyle(.plain).accessibilityLabel(clip.pinned ? "Unpin clip" : "Pin clip")
                Button { model.openActions(for: clip) } label: { Image(systemName: "ellipsis.circle") }
                    .buttonStyle(.plain).accessibilityLabel("Clip actions")
            }
            GeometryReader { geometry in
                if let image {
                    let scale = min(geometry.size.width / max(1, image.size.width), geometry.size.height / max(1, image.size.height))
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
            if !Task.isCancelled { image = loaded; loading = false }
        }
    }
    private func toggleZoom() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) { zoomed.toggle() }
    }
}
