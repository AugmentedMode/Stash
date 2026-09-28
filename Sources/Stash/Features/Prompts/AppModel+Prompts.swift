import SwiftUI
import StashCore

extension AppModel {
    var promptResults: [SavedPrompt] {
        let search = SearchQuery(query)
        return prompts.filter { $0.matches(search) }
    }
    var selectedPrompt: SavedPrompt? {
        promptResults.first { $0.id == promptSelection } ?? promptResults.first
    }
    func openPrompts(from clip: Clip? = nil) {
        closeActions()
        previewOpen = false
        if !promptsActive { query = "" }
        promptsActive = true
        category = nil
        pinnedOnly = false
        if let clip, promptDraft == nil {
            promptDraft = SavedPrompt(name: String(clip.displayTitle.prefix(80)), body: clip.text)
        }
        if promptSelection == nil { promptSelection = promptResults.first?.id }
    }
    func newPrompt() {
        guard !promptLoadFailed, promptDraft == nil else { return }
        promptDraft = SavedPrompt()
    }
    func openSelectedPrompt() {
        guard selectedPrompt != nil else { return }
        promptValues = [:]
        promptDetailOpen = true
    }
    func useSelectedPrompt(copyOnly: Bool) {
        guard let prompt = selectedPrompt else { return }
        if !promptDetailOpen { promptValues = [:] }
        if prompt.rendered(values: promptValues) == nil {
            promptDetailOpen = true
            if let missing = prompt.fields.first(where: {
                (promptValues[$0] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .stashFocusPromptField, object: missing)
                }
            }
            return
        }
        _ = usePrompt(prompt, values: promptValues, pasteImmediately: !copyOnly)
    }
    func movePrompt(_ offset: Int) {
        let list = promptResults
        guard !list.isEmpty else { return }
        let index = list.firstIndex { $0.id == selectedPrompt?.id } ?? 0
        promptSelection = list[max(0, min(list.count - 1, index + offset))].id
    }
    @discardableResult func storePrompt(_ prompt: SavedPrompt) -> Bool {
        guard prompt.isValid else {
            promptError = "Enter a name and prompt within the size limits."
            return false
        }
        var next = prompts
        if let index = next.firstIndex(where: { $0.id == prompt.id }) {
            next[index] = prompt
        } else {
            next.insert(prompt, at: 0)
        }
        return persistPrompts(next)
    }
    @discardableResult func deletePrompt(_ prompt: SavedPrompt) -> Bool {
        persistPrompts(prompts.filter { $0.id != prompt.id })
    }
    private func persistPrompts(_ next: [SavedPrompt]) -> Bool {
        guard !promptLoadFailed else { return false }
        do {
            if !demo { try PromptDisk.save(next, to: promptURL) }
            prompts = next
            promptError = nil
            return true
        } catch {
            promptError = "Prompts couldn’t be saved. Your changes are still here; try again."
            return false
        }
    }
    func usePrompt(_ prompt: SavedPrompt, values: [String: String], pasteImmediately: Bool) -> Bool {
        guard let text = prompt.rendered(values: values) else { return false }
        let clip = Clip(
            sourceName: "Saved prompt", kind: .text, text: text,
            items: [["public.utf8-plain-text": Data(text.utf8)]])
        if pasteImmediately {
            paste(clip, plain: true)
            return true
        }
        return copy(clip, plain: true)
    }
}
