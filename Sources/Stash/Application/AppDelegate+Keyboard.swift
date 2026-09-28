import AppKit
import Carbon
import ApplicationServices
import StashCore

extension AppDelegate {
    func handle(_ event: NSEvent) -> NSEvent? {
        guard panel.isKeyWindow, !model.settingsOpen, model.started else { return event }
        let cmd = event.modifierFlags.contains(.command)
        if model.promptsActive {
            // Leave editor and field keystrokes to SwiftUI. Never dispatch clip actions here.
            if model.promptDraft != nil {
                if event.keyCode == 48 {
                    NotificationCenter.default.post(name: .stashNextPromptEditorField, object: nil)

                    return nil
                }
                if event.keyCode == 53 {
                    model.promptDraft = nil
                    model.promptDetailOpen = false
                    return nil
                }
                return event
            }
            if cmd, event.keyCode == 36 {
                model.useSelectedPrompt(copyOnly: false)
                return nil
            }
            if cmd, event.modifierFlags.contains(.shift),
                event.charactersIgnoringModifiers?.lowercased() == "c"
            {
                model.useSelectedPrompt(copyOnly: true)
                return nil
            }
            if cmd, event.charactersIgnoringModifiers == "e", let prompt = model.selectedPrompt {
                model.promptDraft = prompt
                return nil
            }
            if cmd, event.charactersIgnoringModifiers == "n" {
                model.newPrompt()
                return nil
            }
            if cmd, event.charactersIgnoringModifiers == "f" {
                model.promptDetailOpen = false
                NotificationCenter.default.post(name: .stashFocusSearch, object: nil)
                return nil
            }
            if event.keyCode == 53 {
                if model.promptDetailOpen {
                    model.promptDetailOpen = false
                } else if !model.query.isEmpty {
                    model.query = ""
                } else {
                    dismiss()
                }
                return nil
            }
            if model.promptDetailOpen {
                if event.keyCode == 48, model.selectedPrompt?.fields.isEmpty == false {
                    NotificationCenter.default.post(
                        name: .stashNextPromptField, object: event.modifierFlags.contains(.shift))
                    return nil
                }
                return event
            }
            if [123, 124].contains(event.keyCode), !cmd,
                model.query.isEmpty || event.modifierFlags.contains(.option)
            {
                model.cycleFilter(event.keyCode == 123 ? -1 : 1)
                return nil
            }
            if event.keyCode == 125 {
                model.movePrompt(1)
                return nil
            }
            if event.keyCode == 126 {
                model.movePrompt(-1)
                return nil
            }
            if event.keyCode == 36 {
                model.openSelectedPrompt()
                return nil
            }
            if cmd, event.charactersIgnoringModifiers == "," {
                model.settingsOpen = true
                return nil
            }
            return event
        }
        if model.renameClipID != nil {
            if event.keyCode == 53 {
                model.renameClipID = nil
                return nil
            }
            if event.keyCode == 36 {
                model.finishRename()
                return nil
            }
            return event
        }
        if model.actionClipID != nil {
            if event.keyCode == 53 || (cmd && event.charactersIgnoringModifiers == "k") {
                model.closeActions()
                return nil
            }
            if event.keyCode == 125 {
                model.actionIndex = min(max(0, model.filteredActions.count - 1), model.actionIndex + 1)

                return nil
            }
            if event.keyCode == 126 {
                model.actionIndex = max(0, model.actionIndex - 1)
                return nil
            }
            if event.keyCode == 36 {
                if let clip = model.actionClip, model.filteredActions.indices.contains(model.actionIndex) {
                    model.perform(model.filteredActions[model.actionIndex], on: clip)
                }
                return nil
            }
            return event
        }
        if cmd, event.modifierFlags.contains(.shift), event.charactersIgnoringModifiers?.lowercased() == "p" {
            model.openPrompts()
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "k" {
            model.openActions()
            return nil
        }
        if event.keyCode == 53 {
            if model.previewOpen {
                model.previewOpen = false
            } else if !model.query.isEmpty {
                model.query = ""
            } else {
                dismiss()
            }
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "y", model.selected != nil {
            model.previewOpen.toggle()
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "z", model.canUndoDelete {
            model.undoDelete()
            return nil
        }
        if (event.keyCode == 49 || event.charactersIgnoringModifiers == " "),
            (model.query.isEmpty || !model.searchHasFocus), !cmd, model.selected != nil
        {
            model.previewOpen.toggle()
            return nil
        }
        if [123, 124].contains(event.keyCode), !cmd,
            model.query.isEmpty || event.modifierFlags.contains(.option)
        {
            model.cycleFilter(event.keyCode == 123 ? -1 : 1)
            return nil
        }
        if event.keyCode == 125 {
            model.move(1)
            return nil
        }
        if event.keyCode == 126 {
            model.move(-1)
            return nil
        }
        if event.keyCode == 36, let clip = model.selected {
            model.paste(clip, plain: event.modifierFlags.contains(.shift))
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "p", let clip = model.selected {
            model.togglePin(clip)
            return nil
        }
        if cmd, event.keyCode == 51, let clip = model.selected {
            model.remove(clip)
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "," {
            model.settingsOpen = true
            return nil
        }
        if cmd, event.charactersIgnoringModifiers == "f" {
            NotificationCenter.default.post(name: .stashFocusSearch, object: nil)
            return nil
        }
        if cmd, let number = Int(event.charactersIgnoringModifiers ?? ""), (1...9).contains(number),
            model.results.count >= number
        {
            model.paste(model.results[number - 1])
            return nil
        }
        return event
    }
}
