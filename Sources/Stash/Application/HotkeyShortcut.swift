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
