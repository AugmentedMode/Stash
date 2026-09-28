import AppKit
import SwiftUI

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

final class StashPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum PanelFactory {
    static func make(model: AppModel) -> StashPanel {
        let panel = StashPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        panel.title = model.demo ? "Stash — Preview" : "Stash"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 620, height: 260)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let hosting = TransparentHostingView(rootView: StashView(model: model))
        hosting.safeAreaRegions = []
        // The panel owns its size. Intrinsic sizing feedback through the glass
        // container can otherwise repeatedly invalidate lazy scroll layout.
        hosting.sizingOptions = []
        hosting.frame = NSRect(x: 0, y: 0, width: 620, height: 560)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        if #available(macOS 26.0, *) {
            // Put the actual content inside Apple's glass compositor so its lens,
            // edge illumination, and background adaptation remain system-managed.
            let glass = NSGlassEffectView(frame: hosting.frame)
            glass.style = .clear
            glass.cornerRadius = 24
            glass.contentView = hosting
            glass.autoresizingMask = [.width, .height]
            // Keep the frosted backdrop separate: reducing its opacity must not
            // fade the text or controls. Clear glass supplies the native lens/edge.
            let container = NSView(frame: hosting.frame)
            let backdrop = NSVisualEffectView(frame: hosting.frame)
            backdrop.material = .hudWindow
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.72
            backdrop.autoresizingMask = [.width, .height]
            container.wantsLayer = true
            container.layer?.cornerRadius = 24
            container.layer?.masksToBounds = true
            container.addSubview(backdrop)
            glass.tintColor = NSColor(calibratedWhite: 0.04, alpha: 0.18)
            container.addSubview(glass)
            panel.contentView = container
        } else {
            let material = NSVisualEffectView(frame: hosting.frame)
            material.material = .hudWindow
            material.blendingMode = .behindWindow
            material.state = .active
            material.wantsLayer = true
            material.layer?.cornerRadius = 24
            material.layer?.masksToBounds = true
            material.addSubview(hosting)
            panel.contentView = material
        }
        return panel
    }
}
