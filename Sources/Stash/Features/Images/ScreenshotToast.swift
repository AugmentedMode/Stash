import AppKit
import SwiftUI
import StashCore

/// A small non-activating HUD shown under the menu bar after a screenshot is
/// copied, so the user knows it is ready to paste without opening the palette.
/// Main-thread only, like the rest of the AppKit layer.
final class ScreenshotToastController {
    private final class State: ObservableObject {
        @Published var clip: Clip?
        @Published var visible = false
    }

    private static let size = NSSize(width: 352, height: 92)
    private static let duration: TimeInterval = 2.6
    private let state = State()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var hovering = false
    var onOpen: ((Clip) -> Void)?

    func show(_ clip: Clip) {
        let panel = panel ?? makePanel()
        self.panel = panel
        state.clip = clip
        position(panel)
        if !panel.isVisible || !state.visible {
            state.visible = false
            panel.orderFrontRegardless()
            DispatchQueue.main.async { [state] in
                withAnimation(Self.entrance) { state.visible = true }
            }
        }
        NSAccessibility.post(
            element: panel, notification: .announcementRequested,
            userInfo: [
                .announcement: "Screenshot copied", .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
        scheduleHide(after: Self.duration)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        // A hidden panel never reports the pointer leaving, so a stale hover would pin the next toast.
        hovering = false
        guard let panel, state.visible else { return }
        withAnimation(.easeIn(duration: 0.18)) { state.visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, !self.state.visible else { return }
            panel.orderOut(nil)
        }
    }

    private static var entrance: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.78)
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWork?.cancel()
        guard !hovering else { return }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? .main
        else { return }
        let area = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(x: area.midX - Self.size.width / 2, y: area.maxY - Self.size.height))
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        let view = ScreenshotToastView(
            state: state,
            hover: { [weak self] inside in
                guard let self else { return }
                self.hovering = inside
                if inside { self.hideWork?.cancel() } else { self.scheduleHide(after: 1.2) }
            },
            open: { [weak self] in
                guard let self, let clip = self.state.clip else { return }
                self.hide()
                self.onOpen?(clip)
            })
        let hosting = TransparentHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = hosting
        return panel
    }

    private struct ScreenshotToastView: View {
        @ObservedObject var state: State
        let hover: (Bool) -> Void
        let open: () -> Void
        @State private var image: NSImage?
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack {
                pill
                    .opacity(state.visible ? 1 : 0)
                    .offset(y: state.visible || reduceMotion ? 0 : -14)
                    .scaleEffect(state.visible || reduceMotion ? 1 : 0.96, anchor: .top)
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .preferredColorScheme(.dark)
        }

        private var pill: some View {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.settingsGreen)
                        Text("Screenshot copied").foregroundStyle(.white.opacity(0.95))
                    }.font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 4) {
                        KeyCap(text: "⌘V")
                        Text("to paste").foregroundStyle(Color.muted)
                        Text("·").foregroundStyle(Color.quiet)
                        KeyCap(text: "⌃V")
                        Text("in terminal").foregroundStyle(Color.muted)
                    }.font(.system(size: 11))
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 8).padding(.trailing, 16).padding(.vertical, 8)
            .frame(width: 320)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.canvas.opacity(0.55))
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.1)))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onHover(perform: hover)
            .onTapGesture(perform: open)
            .help("Open in Stash")
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Screenshot copied. Press Command V to paste.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Open in Stash", open)
        }

        private var thumbnail: some View {
            ZStack {
                Color.surface
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "viewfinder").foregroundStyle(Color.quiet)
                }
            }
            .frame(width: 60, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white.opacity(0.12))
            )
            .task(id: state.clip?.id) {
                guard let clip = state.clip else { return }
                image = PreviewCache.cached(clip)
                let loaded = await PreviewCache.load(clip, pixels: 320)
                if !Task.isCancelled { image = loaded }
            }
        }
    }
}
