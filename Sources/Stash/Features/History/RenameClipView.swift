import AppKit
import SwiftUI
import StashCore

struct RenameClipView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename in Stash").font(.system(size: 18, weight: .medium))
            Text("A label for this clip. Its contents and original file stay the same.")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
            TextField("Clip name", text: $model.renameDraft).textFieldStyle(.roundedBorder).focused($focused)
            Text("Leave blank to use the original title.").font(.system(size: 11)).foregroundStyle(
                Color.quiet)
            HStack {
                Spacer()
                Button("Cancel") { model.renameClipID = nil }
                Button("Save name") { model.finishRename() }.buttonStyle(.borderedProminent)
            }
        }.padding(22).background(Color.canvas, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.accent.opacity(0.2)))
            .task {
                await Task.yield()
                focused = true
            }
    }
}
