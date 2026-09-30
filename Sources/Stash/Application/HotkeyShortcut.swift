import AppKit
import Carbon

/// The global shortcut that shows Stash, stored as a Carbon key code and modifier mask.
struct HotkeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var key: String

    static let standard = HotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), key: "V")

    /// Modifier glyphs in the order macOS menus draw them.
    var symbols: [String] {
        var result: [String] = []
        if modifiers & UInt32(controlKey) != 0 { result.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { result.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { result.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { result.append("⌘") }
        return result + [key]
    }
    var display: String { symbols.joined() }

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]
    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11,
        kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19,
    ]

    /// Offered as one-click choices in Settings, least likely to clash first.
    static let suggestions: [HotkeyShortcut] = [
        HotkeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(controlKey | cmdKey), key: "V"),
        HotkeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | cmdKey), key: "V"),
        .standard,
    ]

    /// How well a shortcut works as a global hotkey. A global hotkey wins over every app,
    /// so a clash silently takes that keystroke away everywhere.
    enum Fit: Equatable {
        case good
        /// Usable, but another common command shares it.
        case clash(String)
        /// Would break typing or a system feature, so Stash refuses it.
        case blocked(String)
    }

    var fit: Fit {
        let cmd = UInt32(cmdKey), shift = UInt32(shiftKey), option = UInt32(optionKey)
        let control = UInt32(controlKey)
        let code = Int(keyCode)
        if modifiers == cmd && !Self.functionKeys.contains(code) {
            return .blocked("\(display) is a menu command in most apps. Add ⌃, ⌥ or ⇧.")
        }
        let reserved: [(Int, UInt32, String)] = [
            (kVK_Space, cmd, "opens Spotlight"), (kVK_Space, option | cmd, "opens Finder search"),
            (kVK_Space, control, "switches input sources"),
            (kVK_Space, control | option, "switches input sources"),
            (kVK_Space, control | cmd, "opens the emoji picker"), (kVK_Tab, cmd, "switches apps"),
            (kVK_Tab, shift | cmd, "switches apps"), (kVK_ANSI_Grave, cmd, "switches windows"),
            (kVK_ANSI_3, shift | cmd, "takes a screenshot"), (kVK_ANSI_4, shift | cmd, "takes a screenshot"),
            (kVK_ANSI_5, shift | cmd, "opens Screenshot"),
            (kVK_ANSI_6, shift | cmd, "captures the Touch Bar"),
            (kVK_ANSI_Q, control | cmd, "locks your Mac"), (kVK_Escape, option | cmd, "opens Force Quit"),
        ]
        if let match = reserved.first(where: { $0.0 == code && $0.1 == modifiers }) {
            return .blocked("\(display) \(match.2). Try another shortcut.")
        }
        let clashes: [(Int, UInt32, String)] = [
            (
                kVK_ANSI_V, shift | cmd,
                "pastes without formatting in Slack, Chrome, Notion and many other apps"
            ),
            (kVK_ANSI_V, option | shift | cmd, "is Paste and Match Style in Mail, Notes and Pages"),
            (kVK_ANSI_V, option | cmd, "moves copied files in Finder"),
            (kVK_ANSI_C, shift | cmd, "opens the Computer window in Finder and dev tools in browsers"),
            (kVK_ANSI_F, control | cmd, "toggles full screen"),
        ]
        if let match = clashes.first(where: { $0.0 == code && $0.1 == modifiers }) {
            return .clash("\(display) also \(match.2). While Stash uses it, those apps won’t receive it.")
        }
        return .good
    }

    /// Returns nil for keys that would steal ordinary typing, such as a bare letter or ⇧A.
    init?(event: NSEvent) {
        let code = Int(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        guard carbon & (cmdKey | optionKey | controlKey) != 0 || Self.functionKeys.contains(code) else {
            return nil
        }
        let name =
            Self.namedKeys[code]
            ?? event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let name, !name.isEmpty else { return nil }
        self.init(keyCode: UInt32(code), modifiers: UInt32(carbon), key: name)
    }
    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }
}
