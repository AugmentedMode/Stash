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
        let result = RegisterEventHotKey(
            UInt32(kVK_ANSI_V), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x53545348, id: 1),
            GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr {
            model.shortcutIssue =
                "⌘⇧V is unavailable. Another app or another copy of Stash may be using it. Open Stash from the menu bar."
        }
    }
}
