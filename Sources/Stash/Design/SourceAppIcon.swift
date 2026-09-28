import AppKit
import SwiftUI
import ImageIO
import StashCore

struct SourceAppIcon: View {
    let clip: Clip
    private static var icons: [String: NSImage] = [:]
    private static var missing: Set<String> = []
    private var icon: NSImage? {
        let id = clip.sourceBundle
        guard !id.isEmpty, !Self.missing.contains(id) else { return nil }
        if let image = Self.icons[id] { return image }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            Self.missing.insert(id)
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        Self.icons[id] = image
        return image
    }
    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: clip.kind == .screenshot ? "camera.viewfinder" : "app").resizable()
                    .scaledToFit().foregroundStyle(Color.quiet)
            }
        }.frame(width: 12, height: 12).accessibilityHidden(true)
    }
}
