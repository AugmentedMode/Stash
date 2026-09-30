import AppKit
import SwiftUI
import Carbon
import QuartzCore
import ApplicationServices
import StashCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: AppModel!
    var panel: StashPanel!
    var status: NSStatusItem!
    var hotKey: EventHotKeyRef?
    var hotKeyHandler: EventHandlerRef?
    var keyMonitor: Any?
    var previousApp: NSRunningApplication?
    var workspaceObserver: NSObjectProtocol?
    var presentationPending = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let demo =
            CommandLine.arguments.contains("--demo")
            || Bundle.main.object(forInfoDictionaryKey: "StashPreview") as? Bool == true
        model = AppModel(demo: demo)
        model.showPanel = { [weak self] in self?.show() }
        model.hidePanel = { [weak self] in self?.dismiss() }
        model.onPaste = { [weak self] clip, plain in self?.paste(clip, plain: plain) }
        model.onShortcutChange = { [weak self] in self?.registerHotkey() }
        model.updates.willShowUpdateWindow = { [weak self] in
            self?.presentationPending = false
            self?.panel.orderOut(nil)
        }
        if demo, let index = CommandLine.arguments.firstIndex(of: "--settings") {
            model.settingsOpen = true
            model.requestedSettingsTab = CommandLine.arguments.dropFirst(index + 1).first
        }
        panel = PanelFactory.make(model: model)
        panel.delegate = self
        panel.center()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(
            systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Stash clipboard")
        status.button?.target = self
        status.button?.action = #selector(statusClick)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if Bundle.main.bundleIdentifier != "app.stash.qa" { installHotkey() }
        previousApp = NSWorkspace.shared.frontmostApplication
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self,
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                !self.presentationPending
            else { return }
            self.previousApp = app
            // A queued workspace activation can arrive after show(). Dismissal
            // belongs to applicationDidResignActive, not this notification.

        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event) ?? event
        }
        let main = NSMenu()
        let appMenu = NSMenu()

        appMenu.addItem(
            withTitle: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let root = NSMenuItem()
        root.submenu = appMenu
        main.addItem(root)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")

        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [
            ("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"),
            ("Select All", "selectAll:", "a"),
        ] { editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        edit.submenu = editMenu
        main.addItem(edit)
        NSApp.mainMenu = main
        show()
        if demo, let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
            let path = CommandLine.arguments.dropFirst(index + 1).first
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.writeSnapshot(to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
            }
        }
    }
    func show() {
        if model.settingsOpen, panel.isVisible {
            presentationPending = true
            NSApp.activate(ignoringOtherApps: true)
            finishPresentation()
            return
        }
        let animateEntrance = !panel.isVisible
        presentationPending = true
        if let front = NSWorkspace.shared.frontmostApplication,
            front.processIdentifier != ProcessInfo.processInfo.processIdentifier
        {
            previousApp = front
        }
        model.closeActions()
        model.renameClipID = nil
        if !model.promptsActive {
            model.previewOpen = false
            model.query = ""
            model.selectFilter(nil)
        }
        model.destinationName = previousApp?.localizedName ?? "previous app"
        model.quickPasteReady = AXIsProcessTrusted()
        model.refreshSharePrompt()
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Activation is asynchronous. Order now, then restore key focus once
        // AppKit confirms activation instead of racing another app's focus.
        panel.makeKeyAndOrderFront(nil)
        if NSApp.isActive { finishPresentation() }
        if animateEntrance { revealPanel() }
    }
    private func revealPanel() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            let layer = panel.contentView?.layer
        else { return }
        // Animate presentation only: window geometry and keyboard focus stay live.
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        let rise = CABasicAnimation(keyPath: "transform.translation.y")
        rise.fromValue = layer.isGeometryFlipped ? 5 : -5
        rise.toValue = 0
        let entrance = CAAnimationGroup()
        entrance.animations = [fade, rise]
        entrance.duration = 0.14
        entrance.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(entrance, forKey: "stashEntrance")
    }
    private func finishPresentation() {
        guard presentationPending, NSApp.isActive else { return }
        presentationPending = false
        panel.makeKeyAndOrderFront(nil)
        if let sheet = panel.attachedSheet {
            sheet.makeKeyAndOrderFront(nil)
        } else {
            NotificationCenter.default.post(name: .stashFocusSearch, object: nil)
        }
    }
    func applicationDidBecomeActive(_ notification: Notification) { finishPresentation() }
    func applicationDidResignActive(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !NSApp.isActive, !self.presentationPending else { return }
            // Stay visible while the user grants a permission in System Settings, then come back.
            if self.model.settingsOpen,
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.systempreferences"
            {
                return
            }
            self.model.recordingShortcut = false
            self.model.previewOpen = false
            self.panel.orderOut(nil)
        }
    }
    func togglePanel() {
        if panel.isVisible && panel.isKeyWindow && NSApp.isActive { dismiss() } else { show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return true
    }
    /// Renders the panel for documentation and visual review without Screen Recording access.
    func writeSnapshot(to url: URL) {
        func hosting(in view: NSView) -> NSView? {
            if String(describing: type(of: view)).contains("HostingView") { return view }
            return view.subviews.lazy.compactMap(hosting(in:)).first
        }
        guard let root = panel.contentView, let view = hosting(in: root), let layer = view.layer else {
            return
        }
        let scale = panel.backingScaleFactor
        let size = view.bounds.size
        guard
            let context = CGContext(
                data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        context.scaleBy(x: scale, y: scale)
        // Stand-in for the desktop blur behind the glass.
        context.setFillColor(CGColor(gray: 0.19, alpha: 1))
        context.addPath(CGPath(roundedRect: view.bounds, cornerWidth: 24, cornerHeight: 24, transform: nil))
        context.fillPath()
        if view.isFlipped {
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
        }
        layer.render(in: context)
        guard let image = context.makeImage() else { return }
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? png?.write(to: url)
    }
    func dismiss() {
        presentationPending = false
        model.recordingShortcut = false
        model.previewOpen = false
        panel.orderOut(nil)
        if let previousApp, !previousApp.isTerminated { previousApp.activate(options: []) }
    }
    @objc func statusClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Stash", action: #selector(openAction), keyEquivalent: "")
            menu.addItem(
                withTitle: model.paused ? "Resume capture" : "Pause capture", action: #selector(pauseAction),
                keyEquivalent: "")
            menu.addItem(
                withTitle: "Change Shortcut (\(model.shortcut.display))…",
                action: #selector(changeShortcutAction),
                keyEquivalent: "")
            if model.updates.isAvailable {
                menu.addItem(
                    withTitle: "Check for Updates…", action: #selector(checkForUpdatesAction),
                    keyEquivalent: "")
            }
            menu.addItem(withTitle: "Share Stash…", action: #selector(shareAction), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(
                withTitle: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
                item.target = self
            }
            status.menu = menu
            status.button?.performClick(nil)
            status.menu = nil
        } else {
            togglePanel()
        }
    }
    @objc func openAction() { show() }
    @objc func pauseAction() { model.paused.toggle() }
    @objc func checkForUpdatesAction() { model.updates.checkForUpdates() }
    @objc func shareAction() {
        // The status item is the only view on screen when this menu is open.
        let picker = NSSharingServicePicker(items: [AppModel.shareText, AppModel.shareURL])
        if let button = status.button {
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    @objc func changeShortcutAction() {
        model.openShortcutSettings()
        show()
    }
    func applicationWillTerminate(_ notification: Notification) {
        model.terminate()
        if let hotKey { UnregisterEventHotKey(hotKey) }

        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }

        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }

        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
