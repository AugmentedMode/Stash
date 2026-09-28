import AppKit
import SwiftUI
import StashCore

enum ClipAction: String, Identifiable {
    case paste, copy, plainText, preview, pin, rename, openLink, revealFile, delete
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .paste: return "doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .plainText: return "text.alignleft"
        case .preview: return "eye"
        case .pin: return "pin"
        case .rename: return "pencil"
        case .openLink: return "arrow.up.right"
        case .revealFile: return "folder"
        case .delete: return "trash"
        }
    }
    func title(for clip: Clip, quickPaste: Bool) -> String {
        switch self {
        case .paste: return quickPaste ? "Paste" : "Copy & return"
        case .copy: return "Copy"
        case .plainText: return quickPaste ? "Paste without formatting" : "Copy without formatting & return"
        case .preview: return "Preview"
        case .pin: return clip.pinned ? "Unpin" : "Pin"
        case .rename: return "Rename in Stash…"
        case .openLink: return "Open link"
        case .revealFile: return "Reveal in Finder"
        case .delete: return "Delete clip"
        }
    }
}

extension AppModel {
    var actionClip: Clip? { history.clips.first { $0.id == actionClipID } }
    func actions(for clip: Clip) -> [ClipAction] {
        var actions: [ClipAction] = [.paste, .copy]
        if [.text, .link, .email, .color].contains(clip.kind) { actions.append(.plainText) }
        actions += [.preview, .pin, .rename]
        if clip.linkPresentation != nil { actions.append(.openLink) }
        if !clip.fileURLs.isEmpty { actions.append(.revealFile) }
        actions.append(.delete)
        return actions
    }
    var filteredActions: [ClipAction] {
        guard let clip = actionClip else { return [] }
        return actions(for: clip).filter { actionQuery.isEmpty || $0.title(for: clip, quickPaste: demo || quickPasteReady).localizedStandardContains(actionQuery) }
    }
    func openActions(for clip: Clip? = nil) {
        guard let clip = clip ?? selected else { return }
        actionQuery = ""; actionIndex = 0; actionClipID = clip.id
    }
    func closeActions() { actionClipID = nil; actionQuery = ""; actionIndex = 0 }
    func perform(_ action: ClipAction, on clip: Clip) {
        closeActions()
        // The menu is bound to a clip ID, never to a moving row index.
        guard let current = history.clips.first(where: { $0.id == clip.id }) else { return }
        switch action {
        case .paste: paste(current, plain: false)
        case .copy: copy(current)
        case .plainText: paste(current, plain: true)
        case .preview: selection = current.id; previewOpen = true
        case .pin: togglePin(current)
        case .rename: renameDraft = current.customTitle ?? ""; renameClipID = current.id
        case .openLink:
            if current.linkPresentation != nil, let url = URL(string: current.text.trimmingCharacters(in: .whitespacesAndNewlines)) { NSWorkspace.shared.open(url) }
        case .revealFile:
            let files = current.fileURLs.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
            if files.isEmpty { message("The original file was moved or deleted.") }
            else { NSWorkspace.shared.activateFileViewerSelecting(files) }
        case .delete: remove(current)
        }
    }
    func finishRename() {
        guard let id = renameClipID else { return }
        if let index = history.clips.firstIndex(where: { $0.id == id }) {
            let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            history.clips[index].customTitle = name.isEmpty ? nil : String(name.prefix(160))
            reconcileSelection(); save()
        }
        renameClipID = nil
    }
}

struct ClipActionButtons: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    var body: some View {
        ForEach(model.actions(for: clip)) { action in
            Button(role: action == .delete ? .destructive : nil) { model.perform(action, on: clip) } label: {
                Label(action.title(for: clip, quickPaste: model.demo || model.quickPasteReady), systemImage: action.symbol)
            }
        }
    }
}

struct ActionPalette: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let clip = model.actionClip {
                HStack {
                    Text(clip.displayTitle).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Button { model.closeActions() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Close actions")
                }.foregroundStyle(Color.muted).padding(16)
                TextField("Find an action", text: $model.actionQuery)
                    .textFieldStyle(.plain).font(.system(size: 16)).padding(.horizontal, 16).padding(.bottom, 12)
                    .focused($focused).accessibilityLabel("Find an action")
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 3) {
                            ForEach(Array(model.filteredActions.enumerated()), id: \.element.id) { index, action in
                                Button { model.perform(action, on: clip) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: action.symbol).frame(width: 18)
                                        Text(action.title(for: clip, quickPaste: model.demo || model.quickPasteReady))
                                        Spacer()
                                        if index == model.actionIndex { Text("↵").foregroundStyle(Color.accent) }
                                    }.font(.system(size: 13)).padding(10).contentShape(Rectangle())
                                        .foregroundStyle(action == .delete ? Color(red: 1, green: 0.62, blue: 0.66) : .white)
                                        .background(index == model.actionIndex ? Color.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain).id(action.id)
                                    .accessibilityAddTraits(index == model.actionIndex ? .isSelected : [])
                            }
                            if model.filteredActions.isEmpty { Text("No matching actions").foregroundStyle(Color.muted).padding() }
                        }.padding(8)
                    }.frame(maxHeight: 300)
                        .onChange(of: model.actionIndex) { _, index in
                            if model.filteredActions.indices.contains(index) { proxy.scrollTo(model.filteredActions[index].id) }
                        }
                }
            }
        }
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.accent.opacity(0.2)))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        .task { await Task.yield(); focused = true }
        .onChange(of: model.actionQuery) { _, _ in model.actionIndex = 0 }
    }
}

struct RenameClipView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename in Stash").font(.system(size: 18, weight: .medium))
            Text("A label for this clip. Its contents and original file stay the same.")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
            TextField("Clip name", text: $model.renameDraft).textFieldStyle(.roundedBorder).focused($focused)
            Text("Leave blank to use the original title.").font(.system(size: 11)).foregroundStyle(Color.quiet)
            HStack {
                Spacer()
                Button("Cancel") { model.renameClipID = nil }
                Button("Save name") { model.finishRename() }.buttonStyle(.borderedProminent)
            }
        }.padding(22).background(Color.canvas, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.accent.opacity(0.2)))
            .task { await Task.yield(); focused = true }
    }
}
