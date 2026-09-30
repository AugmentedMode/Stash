import AppKit
import SwiftUI
import StashCore

enum ClipAction: String, Identifiable {
    case paste, copy, plainText, savePrompt, preview, pin, rename, openSource, openLink, revealFile, delete
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .paste: return "doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .plainText: return "text.alignleft"
        case .savePrompt: return "text.bubble"
        case .preview: return "eye"
        case .pin: return "pin"
        case .rename: return "pencil"
        case .openSource: return "arrow.uturn.backward"
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
        case .savePrompt: return "Save as prompt…"
        case .preview: return "Preview"
        case .pin: return clip.pinned ? "Unpin" : "Pin"
        case .rename: return "Rename in Stash…"
        case .openSource:
            if let host = clip.sourceHost { return "Go to source · \(host)" }
            return "Go to source · \(clip.sourceName)"
        case .openLink: return "Open link"
        case .revealFile: return "Reveal in Finder"
        case .delete: return "Delete clip"
        }
    }
}
