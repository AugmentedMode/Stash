import SwiftUI
import StashCore

struct ClipListView: View {
    @ObservedObject var model: AppModel
    let imageNamespace: Namespace.ID
    var body: some View {
        Group {
            if model.results.isEmpty {
                VStack(spacing: 12) {
                    CategoryIllustration(artwork: emptyArtwork, animateEntrance: false)
                        .padding(.bottom, 3)
                    Text(emptyTitle)
                        .font(.system(size: 17, weight: .medium))
                    Text(emptyMessage)
                        .font(.system(size: 13)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    if model.category == .screenshot && model.query.isEmpty {
                        Button(model.screenshotsEnabled ? "Screenshot settings…" : "Set up screenshots…") {
                            model.screenshotSettingsRequested = true
                            model.settingsOpen = true
                        }
                        .buttonStyle(.borderedProminent).tint(Color.accent)
                    }
                    if !model.query.isEmpty || model.category != nil || model.pinnedOnly {
                        Button("Show all clips") {
                            model.query = ""
                            model.selectFilter(nil)
                        }.buttonStyle(.plain).font(.system(size: 13, weight: .medium)).foregroundStyle(
                            Color.accent
                        ).padding(.top, 6)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            let selectedID = model.selected?.id
                            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, clip in
                                // A single stable child per item prevents repeated lazy
                                // placement when a date heading appears or disappears.
                                VStack(spacing: 3) {
                                    if let label = groupLabel(at: index) {
                                        HStack(spacing: 6) {
                                            if clip.pinned {
                                                Image(systemName: "pin.fill").font(.system(size: 9))
                                            }
                                            Text(label).font(.system(size: 12, weight: .medium))
                                            Spacer()
                                        }.foregroundStyle(Color.muted).padding(.horizontal, 16).padding(
                                            .top, index == 0 ? 4 : 14
                                        ).padding(.bottom, 6)
                                    }
                                    PaletteRow(
                                        clip: clip, index: index, query: model.query,
                                        imageNamespace: imageNamespace,
                                        selected: selectedID == clip.id,
                                        onSelect: { model.selection = clip.id },
                                        onPaste: { model.paste(clip) }
                                    )
                                    .contextMenu { ClipActionButtons(model: model, clip: clip) }
                                }.id(clip.id)
                            }
                        }.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 12)
                    }
                    .onChange(of: listPosition) { previous, current in
                        // A filter change also changes selection. Handle both in
                        // one scroll request, after SwiftUI has updated the list.
                        if previous.category != current.category || previous.pinned != current.pinned
                            || previous.query != current.query
                        {
                            if let first = model.results.first { proxy.scrollTo(first.id, anchor: .top) }
                        } else if let id = current.selection {
                            proxy.scrollTo(id)
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private struct ListPosition: Equatable {
        var category: ClipKind?
        var pinned: Bool
        var query: String
        var selection: UUID?
    }
    private var listPosition: ListPosition {
        ListPosition(
            category: model.category, pinned: model.pinnedOnly, query: model.query, selection: model.selection
        )
    }
    private var emptyArtwork: CategoryArtwork {
        if !model.query.isEmpty { return .search }
        if model.pinnedOnly { return .pinned }
        return model.category.flatMap { CategoryArtwork(rawValue: $0.rawValue) } ?? .all
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
        if model.category == .screenshot {
            return model.screenshotsEnabled
                ? "Take a screenshot with ⇧⌘3 or ⇧⌘4. It will appear here once saved."
                : "Take a screenshot. Have it ready to paste. Enable capture in Settings."
        }
        if model.category != nil { return "New copies appear here automatically. You can also look in All." }
        return model.paused
            ? "Resume capture below to start collecting new copies."
            : "Copy something in any app, then press \(model.shortcut.display)."
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
}
