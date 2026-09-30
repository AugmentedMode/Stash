import AppKit
import SwiftUI

/// Shown once, at the bottom of the palette, after Stash has clearly helped.
struct SharePromptCard: View {
    @ObservedObject var model: AppModel
    @State private var anchor: NSView?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accent).frame(width: 30, height: 30)
                .background(Color.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                Text("Know someone who’d like it? Stash is free.").font(.system(size: 11.5))
                    .foregroundStyle(Color.muted)
            }
            Spacer(minLength: 8)
            Button {
                model.shareStash(from: anchor)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up").font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.accent.opacity(0.2), in: Capsule())
            }.buttonStyle(.plain).foregroundStyle(.white).background(AnchorView(view: $anchor))
                .help("Share a link to Stash")
            Button {
                model.starStash()
            } label: {
                Label("Star", systemImage: "star").font(.system(size: 12, weight: .medium))
            }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Star Stash on GitHub")
            Menu {
                Button("Maybe later") { model.snoozeSharePrompt() }
                Button("Don’t ask again") { model.finishSharePrompt() }
            } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .foregroundStyle(Color.quiet).accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.accent.opacity(0.12), .white.opacity(0.03)], startPoint: .leading,
                endPoint: .trailing)
        )
        .accessibilityElement(children: .contain)
    }

    private var headline: String {
        let count = model.recalledCount
        return count > 0
            ? "Stash has brought back \(count) things you’d copied."
            : "Thanks for using Stash."
    }
}

/// Gives the share picker an AppKit view to point at.
private struct AnchorView: NSViewRepresentable {
    @Binding var view: NSView?
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { self.view = view }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
