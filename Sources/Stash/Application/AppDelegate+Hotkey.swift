import AppKit
import Carbon
import ApplicationServices
import StashCore

extension AppDelegate {
    func installHotkey() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, context in
                guard let context else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
                DispatchQueue.main.async { delegate.togglePanel() }
                return noErr
            }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        guard handlerResult == noErr else {
            model.shortcutIssue = "The keyboard shortcut could not start. Open Stash from the menu bar."
            return
        }
        registerHotkey()
    }
    /// Re-registers after the shortcut changes. Recording releases it so the old combo can be typed.
    func registerHotkey() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        guard hotKeyHandler != nil, !model.recordingShortcut else { return }
        let shortcut = model.shortcut
        let result = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x53545348, id: 1),
            GetApplicationEventTarget(), 0, &hotKey)
        model.shortcutIssue =
            result == noErr
            ? nil
            : "\(shortcut.display) is already used by another app. Choose a different shortcut."
    }
    /// Captures the next key press while the shortcut field is recording.
    func recordShortcut(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            model.recordingShortcut = false
            return
        }
        if [kVK_Delete, kVK_ForwardDelete].contains(Int(event.keyCode)),
            event.modifierFlags.intersection([.command, .option, .control]).isEmpty
        {
            model.shortcut = .standard
            model.recordingShortcut = false
            return
        }
        guard let shortcut = HotkeyShortcut(event: event) else {
            NSSound.beep()
            return
        }
        model.shortcut = shortcut
        model.recordingShortcut = false
    }
}
