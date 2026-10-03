import SwiftUI
import AppKit
import ApplicationServices
import StashCore

extension Color {
    static let canvas = Color(red: 0.11, green: 0.115, blue: 0.13)
    static let sidebar = Color(red: 0.14, green: 0.15, blue: 0.22)
    static let surface = Color(red: 0.16, green: 0.165, blue: 0.18)
    static let accent = Color(red: 0.76, green: 0.78, blue: 1.0)
    static let muted = Color.white.opacity(0.66)
    static let quiet = Color.white.opacity(0.54)
    static let line = Color.white.opacity(0.075)
    static func hex(_ value: String) -> Color {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        if s.count == 8 { s = String(s.prefix(6)) }
        let n = UInt32(s, radix: 16) ?? 0
        return Color(
            red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255,
            blue: Double(n & 255) / 255)
    }
}

/// The welcome screen's lavender call to action, sized for empty states.
struct AccentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.canvas)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
