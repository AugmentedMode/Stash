import AppKit
import SwiftUI
import StashCore

struct ClipActionButtons: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    var body: some View {
        ForEach(model.actions(for: clip)) { action in
            Button(role: action == .delete ? .destructive : nil) {
                model.perform(action, on: clip)
            } label: {
                Label(
                    action.title(for: clip, quickPaste: model.demo || model.quickPasteReady),
                    systemImage: action.symbol)
            }
        }
    }
}
