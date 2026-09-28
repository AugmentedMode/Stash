import SwiftUI
import StashCore

struct PromptEditor: View {
    @ObservedObject var model: AppModel
    @Binding var prompt: SavedPrompt
    private enum EditorField { case name, body }
    @FocusState private var editorFocus: EditorField?
    private var valid: Bool { prompt.isValid }
    private var inputFill: Color { Color(red: 0.13, green: 0.135, blue: 0.15).opacity(0.92) }
    private func border(_ field: EditorField) -> Color {
        editorFocus == field ? Color.accent.opacity(0.6) : Color.white.opacity(0.10)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 18, weight: .regular)).foregroundStyle(Color.accent)
                    .frame(width: 38, height: 38)
                    .background(Color.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.prompts.contains { $0.id == prompt.id } ? "Edit prompt" : "New prompt")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Save instructions you use often.").font(.system(size: 11)).foregroundStyle(
                        Color.quiet)
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("NAME").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(
                    Color.muted)
                TextField("e.g. Summarize meeting notes", text: $prompt.name)
                    .font(.system(size: 14, weight: .medium)).textFieldStyle(.plain)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(inputFill, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(border(.name), lineWidth: 1))
                    .focused($editorFocus, equals: .name).accessibilityLabel("Prompt name")
            }
            VStack(spacing: 0) {
                HStack {
                    Text("PROMPT").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(
                        Color.muted)
                    Spacer()
                    Text("Plain text").font(.system(size: 10)).foregroundStyle(Color.quiet)
                }.padding(.horizontal, 14).padding(.vertical, 11)
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                TextEditor(text: $prompt.body).font(.system(size: 14)).lineSpacing(4)
                    .scrollContentBackground(.hidden).padding(.horizontal, 10).padding(.vertical, 10)
                    .overlay(alignment: .topLeading) {
                        if prompt.body.isEmpty {
                            Text(
                                "Write your instructions here…\nUse {{topic}} for a field you can fill in later."
                            )
                            .font(.system(size: 14)).lineSpacing(5).foregroundStyle(Color.quiet.opacity(0.75))
                            .padding(.horizontal, 15).padding(.top, 18)
                            .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 65).accessibilityLabel("Prompt text").focused(
                        $editorFocus, equals: .body)
                HStack(spacing: 6) {
                    Image(systemName: "curlybraces").foregroundStyle(Color.accent.opacity(0.8))
                    Text(
                        prompt.fields.isEmpty
                            ? "Add fields with {{braces}}"
                            : "\(prompt.fields.count) reusable \(prompt.fields.count == 1 ? "field" : "fields")"
                    )
                    Spacer()
                    Text("\(prompt.body.count) characters").monospacedDigit()
                }.font(.system(size: 10)).foregroundStyle(Color.quiet)
                    .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .background(inputFill, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(border(.body), lineWidth: 1))
            if prompt.name.count > SavedPrompt.maximumNameLength
                || prompt.body.utf8.count > SavedPrompt.maximumBodyBytes
            {
                Text("Use a name under 100 characters and prompt text under 64 KB.").font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            HStack {
                Button {
                    model.promptDraft = nil
                    model.promptDetailOpen = false
                } label: {
                    Label("Back", systemImage: "arrow.left").font(.system(size: 12, weight: .medium))
                }.buttonStyle(.plain).foregroundStyle(Color.muted)
                Spacer()
                Button {
                    var saved = prompt
                    saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if model.storePrompt(saved) {
                        model.query = ""
                        model.promptSelection = saved.id
                        model.promptDraft = nil
                        model.promptDetailOpen = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Save prompt").font(.system(size: 12, weight: .semibold))
                        Text("⌘S").font(.system(size: 10, weight: .medium)).opacity(0.65)
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                        .foregroundStyle(valid && !model.promptLoadFailed ? Color.canvas : Color.quiet)
                        .background(
                            valid && !model.promptLoadFailed ? Color.accent : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).disabled(!valid || model.promptLoadFailed)
                    .keyboardShortcut("s", modifiers: .command)
            }
        }.padding(22).task {
            await Task.yield()
            editorFocus = .name
        }
        .onReceive(NotificationCenter.default.publisher(for: .stashNextPromptEditorField)) { _ in
            editorFocus = editorFocus == .name ? .body : .name
        }
    }
}
