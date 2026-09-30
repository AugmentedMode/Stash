import SwiftUI
import AppKit
import ApplicationServices
import StashCore

struct StashView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var categoryPill
    @Namespace private var imageNamespace
    private var surface: some View {
        Group {
            if model.settingsOpen {
                SettingsView(model: model, updates: model.updates)
            } else if model.started {
                palette
            } else {
                WelcomeView(model: model)
            }
        }
        .allowsHitTesting(model.settingsOpen || (model.actionClipID == nil && model.renameClipID == nil))
        .accessibilityHidden(!model.settingsOpen && (model.actionClipID != nil || model.renameClipID != nil))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !model.settingsOpen && (model.actionClipID != nil || model.renameClipID != nil) {
                ZStack {
                    Color.black.opacity(0.25).contentShape(Rectangle()).onTapGesture {
                        model.closeActions()
                        model.renameClipID = nil
                    }.accessibilityHidden(true)
                    if model.renameClipID != nil {
                        RenameClipView(model: model).frame(maxWidth: 380).padding(20)
                    } else {
                        ActionPalette(model: model).frame(maxWidth: 380).padding(20)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            Color(red: 0.035, green: 0.04, blue: 0.065).opacity(reduceTransparency ? 1 : 0.52),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24).strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.16), .white.opacity(0.03), .white.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
        )
        .tint(.accent)

    }
    private var focusedSurface: some View {
        surface
            .onChange(of: model.settingsOpen) { _, open in
                if open {
                    searchFocused = false
                } else {
                    model.quickPasteReady = AXIsProcessTrusted()
                    searchFocused = !model.promptsActive || model.promptDraft == nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashFocusSearch)) { _ in
                if !model.settingsOpen
                    && (!model.promptsActive || (model.promptDraft == nil && !model.promptDetailOpen))
                {
                    searchFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .stashFocusResults)) { _ in
                searchFocused = false
            }
            .onChange(of: searchFocused) { _, focused in model.searchHasFocus = focused }
            .onAppear { searchFocused = true }
    }
    var body: some View {
        focusedSurface
            .onChange(of: model.actionClipID) { _, id in
                if id == nil && model.renameClipID == nil { searchFocused = true }
            }
            .onChange(of: model.renameClipID) { _, id in if id == nil { searchFocused = true } }
            .onChange(of: model.query) { _, _ in
                if model.promptsActive {
                    model.promptDetailOpen = false
                    model.promptSelection = model.promptResults.first?.id
                } else {
                    model.previewOpen = false
                    model.selection = model.results.first?.id
                }
            }
            .onChange(of: model.promptsActive) { _, _ in
                searchFocused = !model.promptsActive || model.promptDraft == nil
            }
            .onChange(of: model.promptDraft?.id) { _, id in searchFocused = id == nil }
            .onChange(of: model.promptDetailOpen) { _, open in searchFocused = !open }
            .onChange(of: model.previewOpen) { _, open in if !open { searchFocused = true } }
    }
    var palette: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.line).frame(height: 0.5)
            ZStack {
                if model.promptsActive {
                    PromptLibraryView(model: model)
                } else if model.previewOpen, let clip = model.selected {
                    VStack(spacing: 0) {
                        HStack {
                            Label("Clip preview", systemImage: "eye").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.muted)
                            Spacer()
                            Button {
                                model.previewOpen = false
                            } label: {
                                Label("Back", systemImage: "arrow.left")
                            }.buttonStyle(.plain).font(.system(size: 12)).accessibilityLabel("Close preview")
                        }.padding(.horizontal, 22).padding(.top, 16)
                        DetailView(model: model, clip: clip, imageNamespace: imageNamespace).id(clip.id)
                    }.frame(maxHeight: .infinity)
                        .transition(
                            .opacity.combined(
                                with: .offset(x: reduceMotion || model.selected?.isVisual == true ? 0 : 8)))
                } else if model.gridActive && !model.results.isEmpty {
                    ImageBrowser(model: model, imageNamespace: imageNamespace).transition(.opacity)
                } else {
                    ClipListView(model: model, imageNamespace: imageNamespace).transition(
                        .opacity.combined(with: .offset(x: reduceMotion ? 0 : -8)))
                }
            }.clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: model.previewOpen)
            PaletteFooter(model: model)
        }
    }
    var header: some View {
        VStack(spacing: 17) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Color.muted)
                TextField(
                    model.promptsActive ? "Search your prompts" : "Search your clipboard", text: $model.query
                )
                .textFieldStyle(.plain).font(.system(size: 20, weight: .regular)).focused($searchFocused)
                .accessibilityLabel(model.promptsActive ? "Search prompts" : "Search clips")
                .disabled(model.promptsActive && model.promptDraft != nil)
                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(
                            Color.muted)
                    }.buttonStyle(.plain).accessibilityLabel("Clear search")
                }
                Text(
                    model.promptsActive
                        ? "\(model.promptResults.count) \(model.promptResults.count == 1 ? "prompt" : "prompts")"
                        : model.demo
                            ? "Sample data"
                            : "\(model.results.count) \(model.results.count == 1 ? "clip" : "clips")"
                ).font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize()
                if model.supportsGrid {
                    Button {
                        model.imageGrid.toggle()
                        model.previewOpen = false
                    } label: {
                        Image(systemName: model.imageGrid ? "list.bullet" : "square.grid.2x2")
                    }.buttonStyle(.plain).foregroundStyle(Color.accent)
                        .help(model.imageGrid ? "Switch to list" : "Switch to thumbnail grid")
                        .accessibilityLabel(model.imageGrid ? "Switch to list" : "Switch to thumbnail grid")
                }
                if model.promptsActive {
                    Button {
                        model.newPrompt()
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.accent)
                    .disabled(model.promptLoadFailed || model.promptDraft != nil)
                    .help("New prompt · ⌘N").accessibilityLabel("New prompt")
                } else {
                    Button {
                        model.openActions()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.muted).disabled(model.selected == nil)
                    .help("Clip actions · ⌘K").accessibilityLabel("Clip actions")
                    Button {
                        model.previewOpen.toggle()
                    } label: {
                        Image(systemName: model.previewOpen ? "eye.slash" : "eye").font(.system(size: 14))
                    }.buttonStyle(.plain).foregroundStyle(Color.muted).disabled(model.selected == nil)
                        .help("Preview · ⌘Y").accessibilityLabel("Preview selected clip")
                }
                Button {
                    model.settingsOpen = true
                } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Settings · ⌘,").accessibilityLabel(
                    "Settings")
            }
            HStack(spacing: 6) {
                chip("All", kind: nil)
                chip("Pinned", kind: nil, pinned: true)
                chip("Text", kind: .text)
                chip("Links", kind: .link)
                chip("Screenshots", kind: .screenshot)
                Button {
                    model.openPrompts()
                } label: {
                    Text("Prompts").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(model.promptsActive ? Color.white : Color.muted)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background { pillBackground(active: model.promptsActive) }
                }.buttonStyle(.plain).help("Saved prompts · ⌘⇧P")
                    .accessibilityAddTraits(model.promptsActive ? .isSelected : [])
                Menu {
                    ForEach([ClipKind.image, .file, .email, .color, .video], id: \.self) { kind in
                        Button {
                            model.selectFilter(kind)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            !model.promptsActive
                                && [ClipKind.image, .file, .email, .color, .video].contains(
                                    model.category ?? .text)
                                ? model.category!.title : "More")

                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background {
                        pillBackground(
                            active: !model.promptsActive
                                && [.image, .file, .email, .color, .video].contains(model.category ?? .text))
                    }
                    .accessibilityLabel("More categories")
                Spacer(minLength: 0)
                if let version = model.availableUpdate {
                    Button {
                        model.updates.checkForUpdates()
                    } label: {
                        Label("Update to \(version)", systemImage: "arrow.down.circle.fill")
                    }
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.accent).buttonStyle(
                        .plain
                    )
                    .help("A new version of Stash is ready to install")
                } else if model.paused {
                    Button {
                        model.paused = false
                    } label: {
                        Label("Resume", systemImage: "pause.circle.fill")
                    }
                    .font(.system(size: 10)).foregroundStyle(.orange).buttonStyle(.plain).help(
                        "Resume clipboard capture")
                } else if !model.demo && !model.quickPasteReady {
                    Button("Copy mode") { model.settingsOpen = true }.font(.system(size: 10)).foregroundStyle(
                        Color.muted
                    ).buttonStyle(.plain)
                        .help(
                            "A clip is copied and you return to your app; press ⌘V to paste. Enable one-step paste in Settings."
                        )
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: model.category)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: model.pinnedOnly)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: model.promptsActive)
        }.padding(.horizontal, 22).padding(.top, 23).padding(.bottom, 16)
    }
    func chip(_ title: String, kind: ClipKind?, pinned: Bool = false) -> some View {
        let active = !model.promptsActive && model.category == kind && model.pinnedOnly == pinned
        return Button {
            model.selectFilter(kind, pinned: pinned)
        } label: {
            HStack(spacing: 4) {
                if pinned { Image(systemName: "pin.fill").font(.system(size: 10)) }
                Text(title).font(.system(size: 12, weight: .medium))
            }.foregroundStyle(active ? Color.white : Color.muted)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background { pillBackground(active: active) }

        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(active ? .isSelected : [])
    }
    @ViewBuilder private func pillBackground(active: Bool) -> some View {
        if active {
            Capsule().fill(Color.accent.opacity(0.16))
                .overlay(Capsule().strokeBorder(Color.accent.opacity(0.16), lineWidth: 0.5))
                .matchedGeometryEffect(id: "category", in: categoryPill)
        }
    }
}
