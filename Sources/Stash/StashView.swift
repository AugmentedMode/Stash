import SwiftUI
import AppKit
import ApplicationServices
import StashCore

extension Color {
    static let canvas = Color(red: 0.11, green: 0.115, blue: 0.13)
    static let sidebar = Color(red: 0.14, green: 0.15, blue: 0.22)
    static let surface = Color(red: 0.16, green: 0.165, blue: 0.18)
    static let accent = Color(red: 0.76, green: 0.78, blue: 1.0)
    static let muted = Color.white.opacity(0.66)
    static let quiet = Color.white.opacity(0.54)
    static let line = Color.white.opacity(0.075)
    static func hex(_ value: String) -> Color {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        if s.count == 8 { s = String(s.prefix(6)) }
        let n = UInt32(s, radix: 16) ?? 0
        return Color(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255)
    }
}
struct KeyCap: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.muted).padding(.horizontal, 5).padding(.vertical, 3).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 4)).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.line)) }
}
struct Glyph: View {
    let kind: ClipKind
    var large = false
    var tint: Color { switch kind { case .text: return .muted; case .link: return Color(red: 0.56, green: 0.73, blue: 0.99); case .email: return Color(red: 0.85, green: 0.65, blue: 0.97); case .color: return .accent; case .image, .screenshot: return .orange; case .video: return .pink; case .file: return .cyan } }
    var body: some View { Image(systemName: kind.symbol).font(.system(size: large ? 24 : 16, weight: .medium)).foregroundStyle(tint).frame(width: large ? 56 : 36, height: large ? 56 : 36).background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: large ? 14 : 10)) }
}
struct StashView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var categoryPill
    var body: some View {
        Group {
            if model.started { palette } else { WelcomeView(model: model) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color(red: 0.035, green: 0.04, blue: 0.065).opacity(reduceTransparency ? 1 : 0.52), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.03), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
        .tint(.accent)
        .sheet(isPresented: $model.settingsOpen, onDismiss: { model.quickPasteReady = AXIsProcessTrusted() }) { SettingsView(model: model) }
        .onReceive(NotificationCenter.default.publisher(for: .init("StashFocusSearch"))) { _ in searchFocused = true }
        .onAppear { searchFocused = true }
        .onChange(of: model.query) { _, _ in model.previewOpen = false; model.selection = model.results.first?.id }
        .onChange(of: model.previewOpen) { _, open in if !open { searchFocused = true } }
    }
    var palette: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.line).frame(height: 0.5)
            ZStack {
                if model.previewOpen, let clip = model.selected {
                    VStack(spacing: 0) {
                        HStack {
                            Label("Clip preview", systemImage: "eye").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                            Spacer()
                            Button { model.previewOpen = false } label: { Label("Back", systemImage: "arrow.left") }.buttonStyle(.plain).font(.system(size: 12)).accessibilityLabel("Close preview")
                        }.padding(.horizontal, 22).padding(.top, 16)
                        DetailView(model: model, clip: clip).id(clip.id)
                    }.frame(maxHeight: .infinity)
                        .transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 8)))
                } else {
                    clipList.transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : -8)))
                }
            }.clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: model.previewOpen)
            footer
        }
    }
    var header: some View {
        VStack(spacing: 17) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .regular)).foregroundStyle(Color.muted)
                TextField("Search your clipboard", text: $model.query)
                    .textFieldStyle(.plain).font(.system(size: 20, weight: .regular)).focused($searchFocused)
                    .accessibilityLabel("Search clips")
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(Color.muted) }.buttonStyle(.plain).accessibilityLabel("Clear search")
                }
                Text("\(model.results.count) \(model.results.count == 1 ? "clip" : "clips")").font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize()
                Button { model.previewOpen.toggle() } label: {
                    Image(systemName: model.previewOpen ? "eye.slash" : "eye").font(.system(size: 14))
                }.buttonStyle(.plain).foregroundStyle(Color.muted).disabled(model.selected == nil)
                    .help("Preview · ⌘Y").accessibilityLabel("Preview selected clip")
                Button { model.settingsOpen = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 14))
                }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Settings · ⌘,").accessibilityLabel("Settings")
            }
            HStack(spacing: 6) {
                chip("All", kind: nil)
                chip("Pinned", kind: nil, pinned: true)
                chip("Text", kind: .text)
                chip("Links", kind: .link)
                chip("Images", kind: .image)
                chip("Screenshots", kind: .screenshot)
                Menu {
                    ForEach([ClipKind.file, .email, .color, .video], id: \.self) { kind in
                        Button { model.selectFilter(kind) } label: { Label(kind.title, systemImage: kind.symbol) }
                    }
                } label: {
                    HStack(spacing: 4) { Text([ClipKind.file, .email, .color, .video].contains(model.category ?? .text) ? model.category!.title : "More"); Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)) }
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.muted)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background { pillBackground(active: [.file, .email, .color, .video].contains(model.category ?? .text)) }
                    .accessibilityLabel("More categories")
                Spacer(minLength: 0)
                if model.paused {
                    Button { model.paused = false } label: { Label("Resume", systemImage: "pause.circle.fill") }
                        .font(.system(size: 10)).foregroundStyle(.orange).buttonStyle(.plain).help("Resume clipboard capture")
                } else if !model.demo && !model.quickPasteReady {
                    Button("Copy mode") { model.settingsOpen = true }.font(.system(size: 10)).foregroundStyle(Color.muted).buttonStyle(.plain)
                        .help("A clip is copied and you return to your app; press ⌘V to paste. Enable one-step paste in Settings.")
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: model.category)
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: model.pinnedOnly)
        }.padding(.horizontal, 22).padding(.top, 23).padding(.bottom, 16)
    }
    func chip(_ title: String, kind: ClipKind?, pinned: Bool = false) -> some View {
        let active = model.category == kind && model.pinnedOnly == pinned
        return Button { model.selectFilter(kind, pinned: pinned) } label: {
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
    var clipList: some View {
        Group {
            if model.results.isEmpty {
                VStack(spacing: 12) {
                    ClipStackIllustration(symbol: !model.query.isEmpty ? "magnifyingglass" : model.pinnedOnly ? "pin.fill" : "text.alignleft")
                        .frame(height: 100).padding(.bottom, 3)
                    Text(emptyTitle)
                        .font(.system(size: 17, weight: .medium))
                    Text(emptyMessage)
                        .font(.system(size: 13)).foregroundStyle(Color.muted).multilineTextAlignment(.center).padding(.horizontal, 24)
                    if model.category == .screenshot && model.query.isEmpty {
                        Button(model.screenshotsEnabled ? "Screenshot settings…" : "Set up screenshots…") { model.screenshotSettingsRequested = true; model.settingsOpen = true }
                            .buttonStyle(.borderedProminent).tint(Color.accent)
                    }
                    if !model.query.isEmpty || model.category != nil || model.pinnedOnly {
                        Button("Show all clips") { model.query = ""; model.selectFilter(nil) }.buttonStyle(.plain).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.accent).padding(.top, 6)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, clip in
                                // A single stable child per item prevents repeated lazy
                                // placement when a date heading appears or disappears.
                                VStack(spacing: 3) {
                                if let label = groupLabel(at: index) {
                                    HStack(spacing: 6) {
                                        if clip.pinned { Image(systemName: "pin.fill").font(.system(size: 9)) }
                                        Text(label).font(.system(size: 12, weight: .medium))
                                        Spacer()
                                    }.foregroundStyle(Color.muted).padding(.horizontal, 16).padding(.top, index == 0 ? 4 : 14).padding(.bottom, 6)
                                }
                                PaletteRow(clip: clip, index: index, selected: model.selected?.id == clip.id, onSelect: { model.selection = clip.id }, onPaste: { model.paste(clip) })
                                    .contextMenu {
                                        Button("Paste", systemImage: "doc.on.clipboard") { model.paste(clip) }
                                        if clip.linkPresentation != nil, let url = URL(string: clip.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            Button("Open original link", systemImage: "arrow.up.right") { NSWorkspace.shared.open(url) }
                                        }
                                        Button("Copy", systemImage: "doc.on.doc") { model.copy(clip) }
                                        Button("Preview", systemImage: "eye") { model.selection = clip.id; model.previewOpen = true }
                                        Button(clip.pinned ? "Unpin" : "Pin", systemImage: "pin") { model.togglePin(clip) }
                                        Divider()
                                        Button("Delete clip", systemImage: "trash", role: .destructive) { model.remove(clip) }
                                    }
                                }.id(clip.id)
                            }
                        }.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 12)
                    }
                    .onChange(of: model.selection) { _, id in if let id { proxy.scrollTo(id) } }
                    .onChange(of: model.category) { _, _ in if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) } }
                    .onChange(of: model.query) { _, _ in if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) } }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var emptyTitle: String {
        if !model.query.isEmpty { return "No clips found" }
        if model.pinnedOnly { return "Keep the good ones close." }
        if let category = model.category { return "No \(category.title.lowercased()) yet" }
        return model.paused ? "Capture is paused" : "Ready for your first copy."
    }
    private var emptyMessage: String {
        if !model.query.isEmpty { return "Try another word, or look in All." }
        if model.pinnedOnly { return "Select a clip and press ⌘P to pin it." }
        if model.category == .screenshot { return model.screenshotsEnabled ? "Take a screenshot with ⇧⌘3 or ⇧⌘4. It will appear here once saved." : "Take a screenshot. Have it ready to paste. Enable capture in Settings." }
        if model.category != nil { return "New copies appear here automatically. You can also look in All." }
        return model.paused ? "Resume capture below to start collecting new copies." : "Copy something in any app, then press ⌘⇧V."
    }
    func groupLabel(at index: Int) -> String? {
        let clips = model.results
        func label(_ clip: Clip) -> String {
            if clip.pinned { return "Pinned" }
            if Calendar.current.isDateInToday(clip.createdAt) { return "Today" }
            if Calendar.current.isDateInYesterday(clip.createdAt) { return "Yesterday" }
            return clip.createdAt.formatted(date: .abbreviated, time: .omitted)
        }
        let value = label(clips[index])
        return index == 0 || label(clips[index - 1]) != value ? value : nil
    }
    var footer: some View {
        VStack(spacing: 0) {
            if let issue = model.shortcutIssue {
                Text(issue).font(.system(size: 12)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            if let error = model.error {
                Text(error).font(.system(size: 12)).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(12)
            } else if let toast = model.toast {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accent)
                    Text(toast).font(.system(size: 12))
                    Spacer()
                    if model.canUndoDelete { Button("Undo") { model.undoDelete() }.buttonStyle(.plain).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.accent) }
                }.padding(.horizontal, 19).padding(.vertical, 10).background(.white.opacity(0.045))
            }
            Rectangle().fill(Color.line).frame(height: 0.5)
            HStack(spacing: 12) {
                hint("↑↓", "Navigate").help("Use Up and Down to select a clip")
                hint("←→", "Category").help("Switch categories. While searching, use Option + Left or Right.")
                Button { if let clip = model.selected { model.paste(clip) } } label: {
                    hint("↵", model.demo || model.quickPasteReady ? "Paste" : "Copy", prominent: true)
                }.disabled(model.selected == nil)
                    .help(model.demo || model.quickPasteReady ? "Paste selected clip" : "Copy and return to \(model.destinationName); then press ⌘V")
                Button { if let clip = model.selected { model.togglePin(clip) } } label: {
                    HStack(spacing: 4) {
                        PinGlyph(pinned: model.selected?.pinned == true).id(model.selected?.id)
                            .font(.system(size: 10))
                        hint("⌘P", model.selected?.pinned == true ? "Unpin" : "Pin")
                    }
                }.disabled(model.selected == nil).accessibilityLabel("Pin or unpin selected clip")
                Button { if let clip = model.selected { model.remove(clip) } } label: { hint("⌘⌫", "Delete") }
                    .disabled(model.selected == nil).help("Delete selected clip. Undo with ⌘Z.").accessibilityLabel("Delete selected clip")
                Spacer(minLength: 0)
                Button { model.hidePanel?() } label: { hint("esc", "Close") }
            }.buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 14)

        }
    }
    func hint(_ key: String, _ title: String, prominent: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.system(size: 11, weight: .regular, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 4).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
            Text(title).font(.system(size: 11, weight: prominent ? .semibold : .regular))
        }.foregroundStyle(prominent ? Color.accent : Color.quiet).fixedSize()
    }
}

struct PaletteRow: View {
    let clip: Clip
    let index: Int
    let selected: Bool
    var onSelect: () -> Void
    var onPaste: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 13) {
            thumbnail.frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.displayTitle).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(selected ? 1 : 0.9)).lineLimit(1)
                HStack(spacing: 5) {
                    Text(clip.linkPresentation.map { $0.service == .web ? $0.host : $0.label + " · " + $0.host } ?? clip.sourceName)
                    Text("·").opacity(0.7)
                    Text(clip.createdAt.formatted(date: .omitted, time: .shortened))
                    PinGlyph(pinned: clip.pinned).font(.system(size: 9)).opacity(clip.pinned ? 1 : 0).padding(.leading, 2)
                }.font(.system(size: 11)).foregroundStyle(Color.quiet).lineLimit(1)
            }
            Spacer(minLength: 6)
            Button(action: onPaste) {
                Text(hovering || selected ? "↵" : index < 9 ? "⌘\(index + 1)" : "")
                    .font(.system(size: 11, weight: .regular)).foregroundStyle(selected ? Color.white.opacity(0.65) : Color.muted.opacity(0.65))
                    .frame(width: 31, height: 29)
                    .background(hovering ? .white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
            }.buttonStyle(.plain).help("Paste this clip").accessibilityLabel("Paste \(clip.displayTitle)")
        }.padding(.horizontal, 15).padding(.vertical, 10)
            .background(selected ? Color.accent.opacity(0.13) : hovering ? .white.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accent.opacity(0.14) : .clear, lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture(perform: onPaste)
            .onHover { hovering = $0 }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(clip.displayTitle)
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityAction(named: "Select", onSelect)
    }
    @ViewBuilder var thumbnail: some View {
        if let link = clip.linkPresentation {
            LinkIcon(service: link.service)
        } else if clip.kind == .color {
            RoundedRectangle(cornerRadius: 8).fill(Color.hex(clip.text)).padding(2).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.10)).padding(2))
        } else if (clip.kind == .image || clip.kind == .screenshot), let image = clip.image {
            Image(nsImage: image).resizable().scaledToFill().frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 6))
        } else if let file = clip.fileURLs.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().scaledToFit()
        } else {
            Image(systemName: clip.kind == .link ? "globe" : clip.kind.symbol).font(.system(size: 19, weight: .regular)).foregroundStyle(Color.white.opacity(0.55))
        }
    }
}

struct DetailView: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Label(clip.kind.title.uppercased(), systemImage: clip.kind.symbol).font(.system(size: 10, weight: .medium)).tracking(1.1).foregroundStyle(Color.muted); Spacer(); Button { model.togglePin(clip) } label: { PinGlyph(pinned: clip.pinned) }.buttonStyle(.plain).help(clip.pinned ? "Unpin (⌘P)" : "Pin (⌘P)").accessibilityLabel(clip.pinned ? "Unpin clip" : "Pin clip")
                Menu { Button("Copy") { model.copy(clip) }; Button("Copy as plain text") { model.copy(clip, plain: true) }; Divider(); Button("Delete clip", role: .destructive) { model.remove(clip) } } label: { Image(systemName: "ellipsis").foregroundStyle(Color.muted) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Clip actions")
            }.padding(.bottom, 23)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let link = clip.linkPresentation {
                        HStack(spacing: 12) {
                            LinkIcon(service: link.service).frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(link.title).font(.system(size: 19, weight: .medium))
                                Text(link.label + " · " + link.host).font(.system(size: 12)).foregroundStyle(Color.muted)
                            }
                        }
                        Text("Original link").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.muted)
                        Text(clip.text).font(.system(size: 13)).textSelection(.enabled).foregroundStyle(Color.white.opacity(0.88)).fixedSize(horizontal: false, vertical: true)
                        if link.titleFromPath { Text("Display name derived from the URL.").font(.system(size: 11)).foregroundStyle(Color.muted) }
                        if let url = URL(string: clip.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            Button("Open original link", systemImage: "arrow.up.right") { NSWorkspace.shared.open(url) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.accent)
                        }
                    } else if clip.kind == .color {
                        RoundedRectangle(cornerRadius: 14).fill(Color.hex(clip.text)).frame(height: 165).overlay(alignment: .bottomLeading) { Text(clip.text.uppercased()).font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(.black.opacity(0.65)).padding(18) }
                        Text("A color worth keeping.").font(.system(size: 18, weight: .medium)).tracking(-0.3)
                    } else if (clip.kind == .image || clip.kind == .screenshot), let image = clip.image {
                        Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("\(Int(image.size.width)) × \(Int(image.size.height)) pixels").font(.system(size: 12)).foregroundStyle(Color.muted)
                    } else if clip.kind == .file || clip.kind == .video {
                        ForEach(clip.fileURLs, id: \.absoluteString) { url in HStack(spacing: 10) { Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 40, height: 40); VStack(alignment: .leading, spacing: 5) { Text(url.lastPathComponent).font(.system(size: 14, weight: .medium)); Text(url.deletingLastPathComponent().path).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(2) } } }
                    } else {
                        Text(clip.text).font(.system(size: clip.kind == .text ? 17 : 16, weight: .regular, design: clip.text.contains("let ") ? .monospaced : .default)).lineSpacing(7).foregroundStyle(Color.white.opacity(0.9)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 20)
            VStack(spacing: 10) {
                meta("Copied from", clip.sourceName)
                meta("Added", clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                meta("Content", clip.kind == .image || clip.kind == .screenshot || clip.kind == .file || clip.kind == .video ? ByteCountFormatter.string(fromByteCount: Int64(clip.byteCount), countStyle: .file) : "\(clip.text.count) characters")
            }.padding(.vertical, 18).overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }

        }.padding(23).background(Color.white.opacity(0.008))
    }
    func meta(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(Color.muted); Spacer(); Text(value).foregroundStyle(Color.white.opacity(0.72)).lineLimit(1) }.font(.system(size: 11)) }
}

/// Installed app icons are resolved once, without fetching any web resources.
struct LinkIcon: View {
    let service: LinkPresentation.Service
    private static let localIcons: [LinkPresentation.Service: NSImage] = {
        var result: [LinkPresentation.Service: NSImage] = [:]
        for (service, bundle) in [(LinkPresentation.Service.notion, "notion.id"), (.figma, "com.figma.Desktop"), (.github, "com.github.GitHubClient")] {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) { result[service] = NSWorkspace.shared.icon(forFile: url.path) }
        }
        return result
    }()
    var body: some View {
        Group {
            if let icon = Self.localIcons[service] {
                Image(nsImage: icon).resizable().scaledToFit()
            } else if service == .notion {
                Text("N").font(.system(size: 23, weight: .bold, design: .serif)).foregroundStyle(.black)
                    .frame(width: 28, height: 28).background(.white, in: RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: symbol).font(.system(size: 21, weight: .regular)).foregroundStyle(tint)
            }
        }.accessibilityHidden(true)
    }
    private var symbol: String {
        switch service {
        case .docs: return "doc.text.fill"
        case .sheets: return "tablecells.fill"
        case .slides: return "rectangle.on.rectangle"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .figma: return "square.stack.3d.up.fill"
        default: return "globe"
        }
    }
    private var tint: Color {
        switch service {
        case .docs: return Color(red: 0.45, green: 0.68, blue: 1)
        case .sheets: return Color(red: 0.40, green: 0.80, blue: 0.58)
        case .slides: return Color(red: 1, green: 0.77, blue: 0.38)
        case .figma: return Color.accent
        default: return Color.white.opacity(0.7)
        }
    }
}
