import AppKit
import ApplicationServices

/// Reads the frontmost window's title through Accessibility, which quick paste already requires.
enum FocusedWindow {
    static func title(of app: NSRunningApplication?) -> String? {
        guard let app, AXIsProcessTrusted() else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        // A hung app must not stall clipboard polling on the main thread.
        AXUIElementSetMessagingTimeout(element, 0.15)
        var window: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window)
                == .success,
            let window, CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }
        var title: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success
        else { return nil }
        return title as? String
    }
}
