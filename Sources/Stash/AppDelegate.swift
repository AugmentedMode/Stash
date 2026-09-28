import AppKit
import SwiftUI
import Carbon
import QuartzCore
import ApplicationServices
import StashCore

final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

final class StashPanel: NSPanel { override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { true } }

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var model: AppModel!
    var panel: StashPanel!
    var status: NSStatusItem!
    var hotKey: EventHotKeyRef?
    var hotKeyHandler: EventHandlerRef?
    var keyMonitor: Any?
    var previousApp: NSRunningApplication?
    var workspaceObserver: NSObjectProtocol?
    private var presentationPending = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let demo = CommandLine.arguments.contains("--demo") || Bundle.main.object(forInfoDictionaryKey: "StashPreview") as? Bool == true
        model = AppModel(demo: demo)
        model.showPanel = { [weak self] in self?.show() }
        model.hidePanel = { [weak self] in self?.dismiss() }
        model.onPaste = { [weak self] clip, plain in self?.paste(clip, plain: plain) }
        panel = StashPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 560), styleMask: [.titled, .fullSizeContentView, .resizable], backing: .buffered, defer: false)
        panel.title = demo ? "Stash — Preview" : "Stash"
        panel.titlebarAppearsTransparent = true; panel.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(button)?.isHidden = true }
        panel.isMovableByWindowBackground = true; panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 620, height: 260)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
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
        panel.center()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Stash clipboard")
        status.button?.target = self; status.button?.action = #selector(statusClick)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if Bundle.main.bundleIdentifier != "app.stash.qa" { installHotkey() }
        previousApp = NSWorkspace.shared.frontmostApplication
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                  !self.presentationPending else { return }
            self.previousApp = app
            // A queued workspace activation can arrive after show(). Dismissal
            // belongs to applicationDidResignActive, not this notification.

        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in self?.handle(event) ?? event }
        let main = NSMenu()
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let root = NSMenuItem(); root.submenu = appMenu; main.addItem(root)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] { editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key) }
        edit.submenu = editMenu; main.addItem(edit); NSApp.mainMenu = main
        show()
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
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        model.closeActions(); model.renameClipID = nil
        model.previewOpen = false; model.query = ""; model.selectFilter(nil)
        model.destinationName = previousApp?.localizedName ?? "previous app"
        model.quickPasteReady = AXIsProcessTrusted()
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
              let layer = panel.contentView?.layer else { return }
        // Animate presentation only: window geometry and keyboard focus stay live.
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1
        let rise = CABasicAnimation(keyPath: "transform.translation.y")
        rise.fromValue = layer.isGeometryFlipped ? 5 : -5; rise.toValue = 0
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
        if let sheet = panel.attachedSheet { sheet.makeKeyAndOrderFront(nil) }
        else { NotificationCenter.default.post(name: .init("StashFocusSearch"), object: nil) }
    }
    func applicationDidBecomeActive(_ notification: Notification) { finishPresentation() }
    func applicationDidResignActive(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !NSApp.isActive, !self.presentationPending,
                  !self.model.settingsOpen else { return }
            self.model.previewOpen = false
            self.panel.orderOut(nil)
        }
    }
    func togglePanel() {
        if model.settingsOpen { show(); return }
        if panel.isVisible && panel.isKeyWindow && NSApp.isActive { dismiss() }
        else { show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        show()
        return true
    }
    func dismiss() {
        presentationPending = false
        model.previewOpen = false
        panel.orderOut(nil)
        if let previousApp, !previousApp.isTerminated { previousApp.activate(options: []) }
    }
    @objc func statusClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Open Stash", action: #selector(openAction), keyEquivalent: "")
            menu.addItem(withTitle: model.paused ? "Resume capture" : "Pause capture", action: #selector(pauseAction), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Stash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
            status.menu = menu; status.button?.performClick(nil); status.menu = nil
        } else { togglePanel() }
    }
    @objc func openAction() { show() }
    @objc func pauseAction() { model.paused.toggle() }
    func installHotkey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { delegate.togglePanel() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        guard handlerResult == noErr else {
            model.shortcutIssue = "The keyboard shortcut could not start. Open Stash from the menu bar."
            return
        }
        let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x53545348, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr {
            model.shortcutIssue = "⌘⇧V is unavailable. Another app or another copy of Stash may be using it. Open Stash from the menu bar."
        }
    }
    func handle(_ event: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow, !model.settingsOpen, model.started else { return event }
        let cmd = event.modifierFlags.contains(.command)
        if model.renameClipID != nil {
            if event.keyCode == 53 { model.renameClipID = nil; return nil }
            if event.keyCode == 36 { model.finishRename(); return nil }
            return event
        }
        if model.actionClipID != nil {
            if event.keyCode == 53 || (cmd && event.charactersIgnoringModifiers == "k") { model.closeActions(); return nil }
            if event.keyCode == 125 { model.actionIndex = min(max(0, model.filteredActions.count - 1), model.actionIndex + 1); return nil }
            if event.keyCode == 126 { model.actionIndex = max(0, model.actionIndex - 1); return nil }
            if event.keyCode == 36 {
                if let clip = model.actionClip, model.filteredActions.indices.contains(model.actionIndex) {
                    model.perform(model.filteredActions[model.actionIndex], on: clip)
                }
                return nil
            }
            return event
        }
        if cmd, event.charactersIgnoringModifiers == "k" { model.openActions(); return nil }
        if event.keyCode == 53 {
            if model.previewOpen { model.previewOpen = false }
            else if !model.query.isEmpty { model.query = "" }
            else { dismiss() }
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "y", model.selected != nil { model.previewOpen.toggle(); return nil }
        if cmd, event.charactersIgnoringModifiers == "z", model.canUndoDelete { model.undoDelete(); return nil }
        if (event.keyCode == 49 || event.charactersIgnoringModifiers == " "), (model.query.isEmpty || !model.searchHasFocus), !cmd, model.selected != nil { model.previewOpen.toggle(); return nil }
        if [123, 124].contains(event.keyCode), !cmd, model.query.isEmpty || event.modifierFlags.contains(.option) {
            model.cycleFilter(event.keyCode == 123 ? -1 : 1); return nil
        }
        if event.keyCode == 125 { model.move(1); return nil }
        if event.keyCode == 126 { model.move(-1); return nil }
        if event.keyCode == 36, let clip = model.selected { model.paste(clip, plain: event.modifierFlags.contains(.shift)); return nil }
        if cmd, event.charactersIgnoringModifiers == "p", let clip = model.selected { model.togglePin(clip); return nil }
        if cmd, event.keyCode == 51, let clip = model.selected { model.remove(clip); return nil }
        if cmd, event.charactersIgnoringModifiers == "," { model.settingsOpen = true; return nil }
        if cmd, event.charactersIgnoringModifiers == "f" { NotificationCenter.default.post(name: .init("StashFocusSearch"), object: nil); return nil }
        if cmd, let number = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(number), model.results.count >= number { model.paste(model.results[number-1]); return nil }
        return event
    }
    func paste(_ clip: Clip, plain: Bool) {
        guard model.copy(clip, plain: plain) else { return }
        guard !model.demo else { model.message("Copied. In preview, paste into any app with ⌘V."); return }
        guard let destination = previousApp, !destination.isTerminated, destination.processIdentifier != ProcessInfo.processInfo.processIdentifier else { model.message("Copied. Switch to an app and press ⌘V."); return }
        guard AXIsProcessTrusted() else {
            // Return to the intended destination even when automatic keystrokes
            // are unavailable. The palette explains this copy-only mode up front.
            dismiss()
            return
        }
        panel.orderOut(nil)
        destination.activate(options: [])
        postPaste(whenActive: destination, remaining: 15)
    }
    func postPaste(whenActive destination: NSRunningApplication, remaining: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self else { return }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier {
                let source = CGEventSource(stateID: .hidSystemState)
                let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
                let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                down?.flags = .maskCommand; up?.flags = .maskCommand
                down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
            } else if remaining > 0 { self.postPaste(whenActive: destination, remaining: remaining - 1) }
            else { self.show(); self.model.message("Copied. The destination app didn’t become active; paste with ⌘V.") }
        }
    }
    func applicationWillTerminate(_ notification: Notification) { model.terminate(); if let hotKey { UnregisterEventHotKey(hotKey) }; if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }; if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) } }
    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
