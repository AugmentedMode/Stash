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
        // Links and files already have their own open actions.
        switch sourceDestination(for: clip) {
        case .page, .app: actions.append(.openSource)
        default: break
        }
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
        case .openSource: goToSource(current)
        case .openLink:
            if current.linkPresentation != nil,
                let url = URL(string: current.text.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                NSWorkspace.shared.open(url)
            }
        case .revealFile: revealFiles(of: current)
        case .delete: remove(current)
        }
    }
    /// Where ⌘O goes. The page a copy came from wins; a copied link or file is its own source.
    enum SourceDestination {
        case page(URL), link(URL), files, app(URL)
        var label: String {
            switch self {
            case .page, .app: return "Source"
            case .link: return "Open link"
            case .files: return "Reveal"
            }
        }
    }
    func sourceDestination(for clip: Clip) -> SourceDestination? {
        if let page = clip.sourceURL, let url = URL(string: page) { return .page(url) }
        if clip.linkPresentation != nil,
            let url = URL(string: clip.text.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return .link(url)
        }
        if !clip.fileURLs.isEmpty { return .files }
        guard !clip.sourceBundle.isEmpty, clip.kind != .screenshot,
            clip.sourceBundle != Bundle.main.bundleIdentifier,
            let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: clip.sourceBundle)
        else { return nil }
        return .app(app)
    }
    func canGoToSource(_ clip: Clip) -> Bool { sourceDestination(for: clip) != nil }
    func goToSource(_ clip: Clip) {
        switch sourceDestination(for: clip) {
        case .page(let url), .link(let url): NSWorkspace.shared.open(url)
        case .files: revealFiles(of: clip)
        case .app(let app):
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        case nil: message("Stash doesn’t know where this clip came from.")
        }
    }
    func revealFiles(of clip: Clip) {
        let files = clip.fileURLs.filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
        if files.isEmpty {
            message("The original file was moved or deleted.")
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(files)
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
