import SwiftUI
import AppKit
import ApplicationServices

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            CategoryIllustration().frame(height: 104)
            Text("A little space for\neverything you copy.").font(.system(size: 31, weight: .medium))
                .tracking(-1.4).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text("Copy freely. Find it instantly. Keep your flow.").font(.system(size: 16)).foregroundStyle(
                Color.muted)
            HStack(spacing: 27) {
                Label("Local history", systemImage: "lock.shield")

                Label("No account", systemImage: "person.crop.circle.badge.checkmark")

                Label("No tracking", systemImage: "eye.slash")
            }.font(.system(size: 12)).foregroundStyle(Color.muted).padding(.top, 4)
            Button {
                model.start()
            } label: {
                HStack(spacing: 34) {
                    Text("Start collecting")
                    Image(systemName: "arrow.right")
                }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.canvas).padding(
                    .horizontal, 23
                ).padding(.vertical, 14).background(Color.accent, in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).padding(.top, 12)
            shortcutCard.padding(.top, 6)
            // Explains the folder-access prompt macOS shows right after Start collecting.
            Label(
                "New screenshots are copied automatically, ready to paste.", systemImage: "camera.viewfinder"
            )
            .font(.system(size: 12)).foregroundStyle(Color.muted)
            Spacer()
            Text(
                "Saves new copies on this Mac for 30 days. Password-manager secrets are skipped.\nStash checks GitHub for updates; your clips never leave your Mac."
            ).font(.system(size: 11)).foregroundStyle(Color.quiet).multilineTextAlignment(.center)
                .lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 32)
                .padding(.bottom, 22)
        }.frame(maxWidth: .infinity).padding(.top, 22)
    }

    /// The one thing to remember, so it gets more weight than anything but the button.
    private var shortcutCard: some View {
        HStack(spacing: 14) {
            Text("Open Stash anytime").font(.system(size: 13, weight: .medium)).foregroundStyle(
                .white.opacity(0.85))
            HStack(spacing: 5) {
                ForEach(model.shortcut.symbols, id: \.self) { symbol in
                    Text(symbol).font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(minWidth: 30, minHeight: 30).padding(.horizontal, symbol.count > 1 ? 6 : 0)
                        .background {
                            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(.white.opacity(0.08))
                                .shadow(color: .black.opacity(0.3), radius: 0, y: 1.5)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(
                                .white.opacity(0.14))
                        )
                }
            }
            Button("Change") { model.openShortcutSettings() }.buttonStyle(.plain)
                .font(.system(size: 12)).foregroundStyle(Color.accent).help("Pick a different shortcut")
        }
        .padding(.leading, 18).padding(.trailing, 16).padding(.vertical, 10)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Open Stash anytime with \(model.shortcut.display)")
    }
}
