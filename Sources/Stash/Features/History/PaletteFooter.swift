import SwiftUI
import StashCore

struct PaletteFooter: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            if let issue = model.shortcutIssue {
                Text(issue).font(.system(size: 12)).foregroundStyle(.orange).frame(
                    maxWidth: .infinity, alignment: .leading
                ).padding(12)
            }
            if let error = model.error {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange).frame(
                    maxWidth: .infinity, alignment: .leading
                ).padding(12)
            } else if let toast = model.toast {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accent)
                    Text(toast).font(.system(size: 12))
                    Spacer()
                    if model.canUndoDelete {
                        Button("Undo") { model.undoDelete() }.buttonStyle(.plain).font(
                            .system(size: 12, weight: .semibold)
                        ).foregroundStyle(Color.accent)
                    }
                }.padding(.horizontal, 19).padding(.vertical, 10).background(.white.opacity(0.045))
            }
            if model.showSharePrompt && !model.promptsActive && model.error == nil {
                Rectangle().fill(Color.line).frame(height: 0.5)
                SharePromptCard(model: model).transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Rectangle().fill(Color.line).frame(height: 0.5)
            if model.promptsActive {
                HStack(spacing: 12) {
                    if model.promptDraft != nil {
                        Button {
                            model.promptDraft = nil
                            model.promptDetailOpen = false
                        } label: {
                            hint("esc", "Back")
                        }
                        hint("⌘S", "Save prompt")
                    } else if model.promptDetailOpen {
                        Button {
                            model.promptDetailOpen = false
                        } label: {
                            hint("esc", "Back")
                        }
                        Text("Saved on this Mac").font(.system(size: 11)).foregroundStyle(Color.quiet)
                    } else {
                        hint("↑↓", "Navigate")
                        Button {
                            model.useSelectedPrompt(copyOnly: true)
                        } label: {
                            hint("⌘⇧C", "Copy")
                        }.disabled(model.selectedPrompt == nil)
                        Button {
                            model.useSelectedPrompt(copyOnly: false)
                        } label: {
                            hint("⌘↵", "Use")
                        }.disabled(model.selectedPrompt == nil)
                        Button {
                            model.openSelectedPrompt()
                        } label: {
                            hint("↵", "Open")
                        }.disabled(model.selectedPrompt == nil)
                        Button {
                            model.newPrompt()
                        } label: {
                            hint("⌘N", "New")
                        }.disabled(model.promptLoadFailed)
                    }
                    Spacer(minLength: 0)
                    Button {
                        model.hidePanel?()
                    } label: {
                        Text("Close").font(.system(size: 11)).foregroundStyle(Color.quiet)
                    }
                }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 14)
            } else {
                HStack(spacing: 12) {
                    hint("↑↓", "Navigate").help("Use Up and Down to select a clip")
                    hint("←→", "Category").help(
                        "Switch categories. While searching, use Option + Left or Right.")
                    Button {
                        if let clip = model.selected { model.paste(clip) }
                    } label: {
                        hint("↵", model.demo || model.quickPasteReady ? "Paste" : "Copy", prominent: true)
                    }.disabled(model.selected == nil)
                        .help(
                            model.demo || model.quickPasteReady
                                ? "Paste selected clip"
                                : "Copy and return to \(model.destinationName); then press ⌘V")
                    Button {
                        if let clip = model.selected { model.togglePin(clip) }
                    } label: {
                        HStack(spacing: 4) {
                            PinGlyph(pinned: model.selected?.pinned == true).id(model.selected?.id)
                                .font(.system(size: 10))
                            hint("⌘P", model.selected?.pinned == true ? "Unpin" : "Pin")
                        }
                    }.disabled(model.selected == nil).accessibilityLabel("Pin or unpin selected clip")
                    Button {
                        model.openActions()
                    } label: {
                        hint("⌘K", "Actions")
                    }
                    .disabled(model.selected == nil).help("Actions for the selected clip · ⌘K")
                    .accessibilityLabel("Open clip actions")
                    if let clip = model.selected, let destination = model.sourceDestination(for: clip) {
                        Button {
                            model.goToSource(clip)
                        } label: {
                            hint("⌘O", destination.label)
                        }
                        .help("Go back to where this was copied · ⌘O")
                        .accessibilityLabel("Go to where the selected clip was copied")
                    }
                    Spacer(minLength: 0)
                    Button {
                        model.hidePanel?()
                    } label: {
                        hint("esc", "Close")
                    }
                }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 14)
            }
        }
    }
    func hint(_ key: String, _ title: String, prominent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.system(size: 11, weight: .regular, design: .monospaced)).padding(.horizontal, 5)
                .padding(.vertical, 4).background(
                    .white.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
            Text(title).font(.system(size: 11, weight: prominent ? .semibold : .regular))
        }.foregroundStyle(prominent ? Color.accent : Color.quiet).fixedSize()
    }
}
