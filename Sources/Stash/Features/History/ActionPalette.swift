import AppKit
import SwiftUI
import StashCore

struct ActionPalette: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let clip = model.actionClip {
                HStack {
                    Text(clip.displayTitle).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Button {
                        model.closeActions()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain).accessibilityLabel("Close actions")
                }.foregroundStyle(Color.muted).padding(16)
                TextField("Find an action", text: $model.actionQuery)
                    .textFieldStyle(.plain).font(.system(size: 16)).padding(.horizontal, 16).padding(
                        .bottom, 12
                    )
                    .focused($focused).accessibilityLabel("Find an action")
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(model.filteredActions.enumerated()), id: \.element.id) {
                                index, action in
                                Button {
                                    model.perform(action, on: clip)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: action.symbol).frame(width: 18)
                                        Text(
                                            action.title(
                                                for: clip, quickPaste: model.demo || model.quickPasteReady))
                                        Spacer()
                                        if index == model.actionIndex {
                                            Text("↵").foregroundStyle(Color.accent)
                                        }
                                    }.font(.system(size: 13)).padding(10).contentShape(Rectangle())
                                        .foregroundStyle(
                                            action == .delete
                                                ? Color(red: 1, green: 0.62, blue: 0.66) : .white
                                        )
                                        .background(
                                            index == model.actionIndex ? Color.accent.opacity(0.14) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain).id(action.id)
                                    .accessibilityAddTraits(index == model.actionIndex ? .isSelected : [])
                            }
                            if model.filteredActions.isEmpty {
                                Text("No matching actions").foregroundStyle(Color.muted).padding()
                            }
                        }.padding(8)
                    }.frame(maxHeight: 300)
                        .onChange(of: model.actionIndex) { _, index in
                            if model.filteredActions.indices.contains(index) {
                                proxy.scrollTo(model.filteredActions[index].id)
                            }
                        }
                }
            }
        }
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.accent.opacity(0.2)))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .task {
            await Task.yield()
            focused = true
        }
        .onChange(of: model.actionQuery) { _, _ in model.actionIndex = 0 }
    }
}
