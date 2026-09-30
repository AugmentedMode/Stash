import SwiftUI
import AppKit

/// A titled group of rows on one glass card, matching the clip list's surfaces.
struct SettingsSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.quiet)
                .padding(.leading, 4).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { content }
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                        Color.white.opacity(0.06), lineWidth: 0.5))
            if let footnote {
                Text(footnote).font(.system(size: 11)).foregroundStyle(Color.quiet)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
            }
        }
    }
}

/// One setting: a tinted icon tile, a title with optional explanation, and a trailing control.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var tint: Color = .accent
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIcon(symbol: icon, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(Color.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }.padding(.horizontal, 14).padding(.vertical, 11).frame(minHeight: 52)
            .accessibilityElement(children: .combine)
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, tint: Color = .accent, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct SettingsIcon: View {
    let symbol: String
    var tint: Color = .accent
    var body: some View {
        Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Hairline between rows, inset to line up with the row titles.
struct SettingsDivider: View {
    var body: some View { Rectangle().fill(Color.line).frame(height: 0.5).padding(.leading, 54) }
}

struct SettingsSwitch: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
    }
}

/// A compact menu that reads like the "More" category chip rather than a stock pop-up button.
struct SettingsMenu<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(label: String, value: Value)]
    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                } label: {
                    if option.value == selection {
                        Label(option.label, systemImage: "checkmark")
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(options.first { $0.value == selection }?.label ?? "")
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.quiet)
            }.font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.88))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
            .accessibilityLabel(title)
    }
}

struct SettingsButtonStyle: ButtonStyle {
    enum Kind { case normal, prominent, destructive }
    var kind: Kind = .normal
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(
                kind == .destructive
                    ? Color(red: 1, green: 0.47, blue: 0.47)
                    : kind == .prominent ? Color.accent : .white.opacity(0.88)
            )
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(
                (kind == .prominent
                    ? Color.accent.opacity(0.16)
                    : kind == .destructive ? Color.red.opacity(0.12) : Color.white.opacity(0.07))
                    .opacity(configuration.isPressed ? 0.6 : 1),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
            .opacity(enabled ? 1 : 0.4).contentShape(Capsule())
    }
}

/// A small status pill with a colored dot, such as "On" or "Needs access".
struct StatusBadge: View {
    let text: String
    var color: Color = .green
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }.font(.system(size: 11, weight: .medium)).foregroundStyle(color.opacity(0.95))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

extension Color {
    static let settingsGreen = Color(red: 0.45, green: 0.86, blue: 0.6)
    static let settingsOrange = Color(red: 1, green: 0.7, blue: 0.35)
    static let settingsBlue = Color(red: 0.45, green: 0.72, blue: 1)
    static let settingsPink = Color(red: 1, green: 0.55, blue: 0.75)
    static let settingsTeal = Color(red: 0.4, green: 0.85, blue: 0.85)
}
