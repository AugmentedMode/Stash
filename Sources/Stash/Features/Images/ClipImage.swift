import AppKit
import SwiftUI
import ImageIO
import StashCore

struct ClipImage: View {
    let clip: Clip
    var pixels = 320
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(Color.quiet)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: "\(clip.fingerprint)-\(pixels)") {
                image = PreviewCache.cached(clip)
                let loaded = await PreviewCache.load(clip, pixels: pixels)
                if !Task.isCancelled { image = loaded }
            }
    }
}
