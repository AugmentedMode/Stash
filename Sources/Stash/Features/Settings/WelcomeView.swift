import SwiftUI
import AppKit
import ApplicationServices

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            CategoryIllustration().frame(height: 120)
            Text("A little space for\neverything you copy.").font(.system(size: 31, weight: .medium))
                .tracking(-1.4).multilineTextAlignment(.center)
            Text("Copy freely. Find it instantly. Keep your flow.").font(.system(size: 16)).foregroundStyle(
                Color.muted)
            HStack(spacing: 27) {
                Label("Local history", systemImage: "lock.shield")

                Label("No account", systemImage: "person.crop.circle.badge.checkmark")

                Label("No tracking", systemImage: "eye.slash")
            }.font(.system(size: 12)).foregroundStyle(Color.muted).padding(.top, 4)
            VStack(spacing: 12) {
                Button {
                    model.start()
                } label: {
                    HStack(spacing: 34) {
                        Text("Start collecting")
                        Image(systemName: "arrow.right")
                    }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.canvas).padding(
                        .horizontal, 23
                    ).padding(.vertical, 14).background(Color.accent, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                Text(
                    "Saves new copies on this Mac for 30 days.\nPassword-manager marked secrets are skipped."
                ).font(.system(size: 12)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .lineSpacing(4)
            }.padding(.top, 12)
            Spacer()
            HStack(spacing: 7) {
                Text("Always one shortcut away").foregroundStyle(Color.muted)
                ForEach(model.shortcut.symbols, id: \.self) { KeyCap(text: $0) }
            }.font(.system(size: 12)).padding(.bottom, 24)
        }.frame(maxWidth: .infinity).padding(.top, 22)
    }
}
