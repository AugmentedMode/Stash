import AppKit
import Carbon
import ApplicationServices
import StashCore

extension AppDelegate {
    func paste(_ clip: Clip, plain: Bool) {
        guard model.copy(clip, plain: plain) else { return }
        guard !model.demo else {
            model.message("Copied. In preview, paste into any app with ⌘V.")
            return
        }
        guard let destination = previousApp, !destination.isTerminated,
            destination.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            model.message("Copied. Switch to an app and press ⌘V.")
            return
        }
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
                down?.flags = .maskCommand
                up?.flags = .maskCommand
                down?.post(tap: .cghidEventTap)
                up?.post(tap: .cghidEventTap)
            } else if remaining > 0 {
                self.postPaste(whenActive: destination, remaining: remaining - 1)
            } else {
                self.show()

                self.model.message("Copied. The destination app didn’t become active; paste with ⌘V.")
            }
        }
    }
}
