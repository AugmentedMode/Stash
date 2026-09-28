import SwiftUI
import StashCore

struct PromptLibraryView: View {
    @ObservedObject var model: AppModel
    @State private var deleting: SavedPrompt?
    @State private var copied = false
    @FocusState private var focusedField: String?

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.promptError {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange).padding(12)
            }
            if let draft = model.promptDraft {
                PromptEditor(
                    model: model,
                    prompt: Binding(get: { model.promptDraft ?? draft }, set: { model.promptDraft = $0 })
                )
                .id(draft.id)
            } else if model.promptDetailOpen, let prompt = model.selectedPrompt {
                promptDetail(prompt).padding(22)
            } else if model.promptResults.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "text.bubble").font(.system(size: 32, weight: .light)).foregroundStyle(
                        Color.accent)
                    Text(model.query.isEmpty ? "Your best prompts, ready to reuse." : "No matching prompts")
                        .font(.system(size: 17, weight: .medium))
                    Text(
                        model.query.isEmpty
                            ? "Keep the prompts you reach for often. Add optional fields like {{topic}} to make them your own each time."
                            : "Try another name or a word from the prompt."
                    )
                    .font(.system(size: 13)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
                    if model.query.isEmpty {
                        Button("Create a prompt", systemImage: "plus") { model.newPrompt() }
                            .buttonStyle(.borderedProminent).disabled(model.promptLoadFailed)
                    } else {
                        Button("Clear search") { model.query = "" }.buttonStyle(.plain).foregroundStyle(
                            Color.accent)
                    }
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                promptList
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .confirmationDialog(
                "Delete this saved prompt?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("Delete prompt", role: .destructive) {
                    if let deleting, model.deletePrompt(deleting) {
                        model.promptDetailOpen = false
                        model.promptSelection = model.promptResults.first?.id
                    }
                    deleting = nil
                }
            }
            .onChange(of: model.selectedPrompt) { _, _ in
                copied = false
                model.promptValues = [:]
            }
            .onChange(of: model.promptValues) { _, _ in copied = false }
            .onReceive(NotificationCenter.default.publisher(for: .stashFocusPromptField)) { note in
                focusedField = note.object as? String
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashNextPromptField)) { note in
                guard let fields = model.selectedPrompt?.fields, !fields.isEmpty else { return }
                let reverse = note.object as? Bool == true
                if let current = focusedField, let index = fields.firstIndex(of: current) {
                    focusedField = fields[(index + (reverse ? -1 : 1) + fields.count) % fields.count]
                } else {
                    focusedField = reverse ? fields.last : fields.first
                }
            }
    }

    private var promptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    let selectedID = model.selectedPrompt?.id
                    HStack {
                        Text("Ready to reuse").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(model.demo ? "Sample session" : "Saved on this Mac").font(.system(size: 11))
                    }.foregroundStyle(Color.quiet).padding(.horizontal, 15).padding(.vertical, 8)
                    ForEach(model.promptResults) { prompt in
                        Button {
                            model.promptSelection = prompt.id
                            model.openSelectedPrompt()
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: "text.bubble").font(.system(size: 17)).foregroundStyle(
                                    Color.accent
                                )
                                .frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 5) {
                                    HighlightedText(value: prompt.name, query: model.query).font(
                                        .system(size: 14, weight: .medium)
                                    ).lineLimit(1)
                                    HighlightedText(value: prompt.body, query: model.query).font(
                                        .system(size: 12)
                                    ).foregroundStyle(Color.muted).lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                if !prompt.fields.isEmpty {
                                    Text(
                                        "\(prompt.fields.count) \(prompt.fields.count == 1 ? "field" : "fields")"
                                    ).font(.system(size: 10)).foregroundStyle(Color.quiet)
                                }
                                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.quiet)
                            }.padding(.horizontal, 15).padding(.vertical, 12).contentShape(Rectangle())
                                .background(
                                    selectedID == prompt.id
                                        ? Color.accent.opacity(0.13) : .clear,
                                    in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).id(prompt.id)
                            .accessibilityLabel(prompt.name)
                            .accessibilityAddTraits(selectedID == prompt.id ? .isSelected : [])
                            .contextMenu {
                                Button("Open") {
                                    model.promptSelection = prompt.id
                                    model.openSelectedPrompt()
                                }
                                Button("Edit") { model.promptDraft = prompt }
                                Button("Delete", role: .destructive) { deleting = prompt }
                            }
                    }
                }.padding(12)
            }.onChange(of: model.promptSelection) { _, id in if let id { proxy.scrollTo(id) } }
        }
    }

    private func promptDetail(_ prompt: SavedPrompt) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    model.promptDetailOpen = false
                } label: {
                    Label("Prompts", systemImage: "arrow.left")
                }
                .buttonStyle(.plain).foregroundStyle(Color.muted)
                Spacer()
                Button("Edit", systemImage: "pencil") { model.promptDraft = prompt }
                    .buttonStyle(.plain)
                Button {
                    deleting = prompt
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain).foregroundStyle(Color.muted).accessibilityLabel("Delete prompt")
            }.font(.system(size: 12))
            Text(prompt.name).font(.system(size: 20, weight: .medium)).lineLimit(2)
            VStack(alignment: .leading, spacing: 8) {
                Text("PROMPT").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(
                    Color.quiet)
                ScrollView {
                    Text(prompt.preview(values: model.promptValues))
                        .font(.system(size: 14)).lineSpacing(4).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minHeight: 54, maxHeight: prompt.fields.isEmpty ? .infinity : 120)
            }.padding(14)
                .background(.black.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
            if !prompt.fields.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(prompt.fields, id: \.self) { field in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(field.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.muted)
                                TextField(
                                    "Add \(field.lowercased())…",
                                    text: Binding(
                                        get: { model.promptValues[field] ?? "" },
                                        set: { model.promptValues[field] = $0 }), axis: .vertical
                                )
                                .font(.system(size: 14)).textFieldStyle(.plain).lineLimit(1...4)
                                .padding(.horizontal, 12).padding(.vertical, 11)
                                .background(
                                    .white.opacity(focusedField == field ? 0.065 : 0.035),
                                    in: RoundedRectangle(cornerRadius: 9)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9).strokeBorder(
                                        focusedField == field ? Color.accent.opacity(0.55) : Color.line,
                                        lineWidth: 1)
                                )
                                .accessibilityLabel(field).focused($focusedField, equals: field)
                                .onKeyPress(keys: [.tab], phases: .down) { key in
                                    let fields = prompt.fields
                                    guard let index = fields.firstIndex(of: field) else { return .ignored }
                                    let offset = key.modifiers.contains(.shift) ? -1 : 1
                                    focusedField = fields[(index + offset + fields.count) % fields.count]
                                    return .handled
                                }
                                .task {
                                    if field == prompt.fields.first {
                                        await Task.yield()
                                        focusedField = field
                                    }
                                }
                            }
                        }
                    }.padding(1)
                }
            }
            HStack {
                Text(copied ? "Copied" : prompt.fields.isEmpty ? "Ready to use" : "Tab to the next field")
                    .font(.system(size: 11)).foregroundStyle(Color.quiet)
                Spacer()
                Button {
                    copied = model.usePrompt(prompt, values: model.promptValues, pasteImmediately: false)
                } label: {
                    HStack(spacing: 8) {
                        Text("Copy")
                        Text("⌘⇧C").font(.system(size: 10)).foregroundStyle(Color.quiet)
                    }
                }.help("Copy prompt · ⌘⇧C").accessibilityLabel("Copy prompt")
                Button {
                    _ = model.usePrompt(prompt, values: model.promptValues, pasteImmediately: true)
                } label: {
                    HStack(spacing: 8) {
                        Text(model.quickPasteReady && !model.demo ? "Paste" : "Copy & return")
                        Text("⌘↵").font(.system(size: 10))
                    }
                }.buttonStyle(.borderedProminent).help("Use prompt · ⌘Return")
            }.disabled(prompt.rendered(values: model.promptValues) == nil)
        }
    }
}
