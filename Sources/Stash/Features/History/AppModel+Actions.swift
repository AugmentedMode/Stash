import AppKit
import SwiftUI
import StashCore

extension AppModel {
    var actionClip: Clip? { history.clips.first { $0.id == actionClipID } }
    func actions(for clip: Clip) -> [ClipAction] {
        var actions: [ClipAction] = [.paste, .copy]
        if [.text, .link, .email, .color].contains(clip.kind) { actions.append(.plainText) }
        if clip.kind == .text { actions.append(.savePrompt) }
        actions += [.preview, .pin, .rename]
        if clip.linkPresentation != nil { actions.append(.openLink) }
        if !clip.fileURLs.isEmpty { actions.append(.revealFile) }
        actions.append(.delete)
        return actions
    }
    var filteredActions: [ClipAction] {
        guard let clip = actionClip else { return [] }
        return actions(for: clip).filter {
            actionQuery.isEmpty
                || $0.title(for: clip, quickPaste: demo || quickPasteReady).localizedStandardContains(
                    actionQuery)
        }
    }
    func openActions(for clip: Clip? = nil) {
        guard let clip = clip ?? selected else { return }
        actionQuery = ""
        actionIndex = 0
        actionClipID = clip.id
    }
    func closeActions() {
        actionClipID = nil
        actionQuery = ""
        actionIndex = 0
    }
    func perform(_ action: ClipAction, on clip: Clip) {
        closeActions()
        // The menu is bound to a clip ID, never to a moving row index.
        guard let current = history.clips.first(where: { $0.id == clip.id }) else { return }
        switch action {
        case .paste: paste(current, plain: false)
        case .copy: copy(current)
        case .plainText: paste(current, plain: true)
        case .savePrompt: openPrompts(from: current)
        case .preview:
            selection = current.id
            previewOpen = true
        case .pin: togglePin(current)
        case .rename:
            renameDraft = current.customTitle ?? ""
            renameClipID = current.id
        case .openLink:
            if current.linkPresentation != nil,
                let url = URL(string: current.text.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                NSWorkspace.shared.open(url)
            }
        case .revealFile:
            let files = current.fileURLs.filter {
                $0.isFileURL && FileManager.default.fileExists(atPath: $0.path)
            }
            if files.isEmpty {
                message("The original file was moved or deleted.")
            } else {
                NSWorkspace.shared.activateFileViewerSelecting(files)
            }
        case .delete: remove(current)
        }
    }
    func finishRename() {
        guard let id = renameClipID else { return }
        if let index = history.clips.firstIndex(where: { $0.id == id }) {
            let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            history.clips[index].customTitle = name.isEmpty ? nil : String(name.prefix(160))
            reconcileSelection()
            save()
        }
        renameClipID = nil
    }
}
