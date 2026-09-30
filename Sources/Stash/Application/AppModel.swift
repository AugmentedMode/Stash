import AppKit
import Combine
import SwiftUI
import StashCore

final class AppModel: ObservableObject {
    @Published var history = History() { didSet { cachedResults = nil } }
    @Published var query = "" { didSet { cachedResults = nil } }
    @Published var category: ClipKind? { didSet { cachedResults = nil } }
    @Published var pinnedOnly = false { didSet { cachedResults = nil } }
    @Published var selection: UUID?
    @Published var paused = false {
        didSet { if oldValue != paused { configureMonitoring(skipCurrent: true) } }
    }
    @Published private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var destinationName = "previous app"
    @Published var quickPasteReady = false
    @Published var shortcutIssue: String?
    @Published var shortcut: HotkeyShortcut {
        didSet {
            guard shortcut != oldValue else { return }
            if let data = try? JSONEncoder().encode(shortcut) { defaults.set(data, forKey: "shortcut") }
            onShortcutChange?()
        }
    }
    /// While true, the next key press becomes the shortcut and the current one is released.
    @Published var recordingShortcut = false {
        didSet {
            guard recordingShortcut != oldValue else { return }
            shortcutRecordingHint = nil
            onShortcutChange?()
        }
    }
    /// Opens Settings → General, where the shortcut is changed.
    func openShortcutSettings() {
        requestedSettingsTab = "General"
        settingsOpen = true
    }
    /// Why the last key press while recording was refused.
    @Published var shortcutRecordingHint: String?
    var onShortcutChange: (() -> Void)?
    var screenshotSettingsRequested = false
    /// Preview builds can open a settings tab directly with `--settings <tab>`.
    @Published var requestedSettingsTab: String?
    @Published var promptsActive = false
    @Published var promptSelection: UUID?
    @Published var promptDetailOpen = false
    @Published var promptValues: [String: String] = [:]
    @Published var prompts: [SavedPrompt] = []
    @Published var promptDraft: SavedPrompt?
    @Published var promptError: String?
    var promptLoadFailed = false
    var promptURL: URL { diskURL.deletingLastPathComponent().appendingPathComponent("prompts.json") }
    @Published var settingsOpen = false
    @Published var previewOpen = false
    @Published var imageGrid: Bool { didSet { defaults.set(imageGrid, forKey: "imageGrid") } }
    @Published var searchHasFocus = true
    @Published var actionClipID: UUID?
    @Published var actionQuery = ""
    @Published var actionIndex = 0
    @Published var renameClipID: UUID?
    @Published var renameDraft = ""
    var supportsGrid: Bool { !promptsActive && (category == .image || category == .screenshot) }
    var gridActive: Bool { supportsGrid && imageGrid && !previewOpen }

    /// The one-time "share Stash" card, shown after Stash has clearly helped. Counted on this Mac only.
    @Published var showSharePrompt = false
    var sharePrompt = SharePrompt() {
        didSet {
            if let data = try? JSONEncoder().encode(sharePrompt) { defaults.set(data, forKey: "sharePrompt") }
        }
    }
    /// Old clips this person has brought back, for the share card's thank-you line.
    var recalledCount: Int { sharePrompt.recalls }
    @Published var canUndoDelete = false
    private var deletedClip: Clip?
    @Published var toast: String?
    @Published var error: String?
    private var historyLoadFailed = false
    @Published var started: Bool
    @Published var retention: Int {
        didSet {
            defaults.set(retention, forKey: "retention")
            expire()
            save()
        }
    }
    @Published var memoryOnly: Bool {
        didSet {
            defaults.set(memoryOnly, forKey: "memoryOnly")
            save(immediately: true)
        }
    }
    @Published var historyLimit: Int {
        didSet {
            defaults.set(historyLimit, forKey: "historyLimit")
            history.enforceLimits(count: historyLimit)
            reconcileSelection()
            save()
        }
    }
    /// Window titles and page addresses saved with each clip. Turning it off erases them.
    @Published var rememberSourceDetails: Bool {
        didSet {
            defaults.set(rememberSourceDetails, forKey: "rememberSourceDetails")
            guard !rememberSourceDetails, oldValue else { return }
            for index in history.clips.indices {
                history.clips[index].sourceTitle = nil
                history.clips[index].sourceURL = nil
            }
            save()
        }
    }
    @Published var excluded: [String] { didSet { defaults.set(excluded, forKey: "excluded") } }
    @Published var screenshotsEnabled: Bool {
        didSet {
            defaults.set(screenshotsEnabled, forKey: "screenshotsEnabled")
            configureScreenshots()
        }
    }
    @Published var screenshotAutoCopy: Bool {
        didSet { defaults.set(screenshotAutoCopy, forKey: "screenshotAutoCopy") }
    }
    @Published var screenshotFolder: String {
        didSet {
            defaults.set(screenshotFolder, forKey: "screenshotFolder")
            configureScreenshots()
        }
    }
    @Published var screenshotIssue: String?
    private let screenshots = ScreenshotObserver()
    private var screenshotGeneration = UUID()
    private var lastClipboardActivity = Date.distantPast
    var screenshotStatus: String {
        if demo { return "Preview mode · capture is off" }
        if !screenshotsEnabled { return "Off · your clipboard stays as it is" }
        if paused || monitoring.isSuspended { return "Paused · resumes with clipboard capture" }
        return screenshotIssue ?? "Watching for new screenshots"
    }
    func chooseScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your screenshot save folder"
        panel.message =
            "Choose the same folder as Screenshot → Options → Save to. Only new macOS screenshots will be collected."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: screenshotFolder)
        if panel.runModal() == .OK, let url = panel.url { screenshotFolder = url.path }
    }
    private func configureScreenshots() {
        screenshots.stop()
        screenshotGeneration = UUID()
        screenshotIssue = nil
        guard started, !demo, screenshotsEnabled, !paused, !monitoring.isSuspended else { return }
        let generation = screenshotGeneration
        screenshots.start(
            folder: URL(fileURLWithPath: screenshotFolder),
            receive: { [weak self] clip in
                guard let self, self.screenshotGeneration == generation else { return }
                self.history.insert(clip, limit: self.historyLimit)
                self.save()
                if self.selection == nil { self.selection = self.results.first?.id }
                // Do not overwrite a copy made while this image was being prepared.
                if self.screenshotAutoCopy && !self.clipboard.hasChanges
                    && self.lastClipboardActivity < clip.createdAt
                {
                    if ClipboardCodec.restore(clip, to: .general) {
                        self.clipboard.skipCurrentChange()
                        self.message("Screenshot copied · ready to paste")
                    }
                } else {
                    self.message("Screenshot saved to history")
                }
            },
            failure: { [weak self] in
                guard let self, self.screenshotGeneration == generation else { return }
                self.screenshotIssue = "Folder unavailable. Choose it again to restore access."
            })
    }
    let demo: Bool
    let updates: UpdateController
    /// Mirrors `updates.availableVersion` so the palette redraws when an update is found.
    @Published var availableUpdate: String?
    private var updateSubscription: AnyCancellable?
    let defaults: UserDefaults
    /// The pre-1.0.5 single-file history, migrated into `History/` on first launch.
    let diskURL: URL
    var showPanel: (() -> Void)?
    var hidePanel: (() -> Void)?
    var onPaste: ((Clip, Bool) -> Void)?
    private lazy var monitoring = MonitoringController(
        powerChanged: { [weak self] value in
            if self?.lowPower != value { self?.lowPower = value }
        },
        poll: { [weak self] in self?.poll() },
        suspensionChanged: { [weak self] in
            self?.clipboard.skipCurrentChange()
            self?.configureScreenshots()
        },
        willSleep: { [weak self] in self?.writer.flush() }
    )
    private let clipboard = ClipboardObserver()
    private lazy var store = HistoryStore(
        directory: diskURL.deletingLastPathComponent().appendingPathComponent("History"), legacyURL: diskURL)
    private lazy var writer = HistoryWriter(
        write: { [weak self, store] snapshot in
            try store.save(snapshot)
            DispatchQueue.main.async { self?.error = nil }
        },
        onError: { [weak self] _ in
            DispatchQueue.main.async {
                self?.error = "History couldn’t be saved. New clips are available for this session only."
            }
        })
    private var cachedResults: [Clip]?
    private var toastID = UUID()
    private var nextExpiry = Date().addingTimeInterval(300)
    var results: [Clip] {
        if let cachedResults { return cachedResults }
        let filtered = history.filtered(query: query, kind: category, pinnedOnly: pinnedOnly)
        cachedResults = filtered
        return filtered
    }
    var selected: Clip? { results.first { $0.id == selection } ?? results.first }
    init(demo: Bool) {
        self.demo = demo
        updates = UpdateController(enabled: !demo && Bundle.main.bundleIdentifier != "app.stash.qa")
        defaults = demo ? UserDefaults(suiteName: "app.stash.preview")! : .standard
        diskURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stash/history.json")
        imageGrid = defaults.object(forKey: "imageGrid") as? Bool ?? true
        started = demo || defaults.bool(forKey: "started")
        retention = defaults.object(forKey: "retention") as? Int ?? 30
        historyLimit = defaults.object(forKey: "historyLimit") as? Int ?? 500
        rememberSourceDetails = defaults.object(forKey: "rememberSourceDetails") as? Bool ?? true
        shortcut =
            defaults.data(forKey: "shortcut").flatMap {
                try? JSONDecoder().decode(HotkeyShortcut.self, from: $0)
            }
            ?? .standard
        memoryOnly = defaults.bool(forKey: "memoryOnly")
        screenshotsEnabled = defaults.bool(forKey: "screenshotsEnabled")
        screenshotAutoCopy = defaults.object(forKey: "screenshotAutoCopy") as? Bool ?? true
        screenshotFolder =
            defaults.string(forKey: "screenshotFolder")
            ?? (UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location").map {
                ($0 as NSString).expandingTildeInPath
            }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        excluded = defaults.stringArray(forKey: "excluded") ?? ClipboardCodec.defaultExclusions.sorted()
        sharePrompt =
            defaults.data(forKey: "sharePrompt").flatMap {
                try? JSONDecoder().decode(SharePrompt.self, from: $0)
            } ?? SharePrompt()
        if demo {
            history = Self.examples()
        } else if !memoryOnly {
            do { history = try store.load() } catch {
                historyLoadFailed = true

                self.error = "Your saved history couldn’t be opened. It has been left untouched."
            }
        }
        if !demo {
            do { prompts = try PromptDisk.load(from: promptURL) } catch {
                promptLoadFailed = true

                promptError = "Saved prompts couldn’t be opened. The file has been left untouched."
            }
        }
        expire()
        updateSubscription = updates.$availableVersion.sink { [weak self] in self?.availableUpdate = $0 }
        selection = results.first?.id
        if started && !demo { startMonitoring() }
    }
    func start() {
        started = true
        defaults.set(true, forKey: "started")
        startMonitoring()
    }
    private func startMonitoring() {
        configureMonitoring(skipCurrent: true)
    }

    private func configureMonitoring(skipCurrent: Bool) {
        guard !demo, started else { return }
        if skipCurrent { clipboard.skipCurrentChange() }
        monitoring.start(paused: paused)
        configureScreenshots()
    }
    func poll() {
        if Date() >= nextExpiry {
            nextExpiry = Date().addingTimeInterval(300)
            let count = history.clips.count
            expire()
            if count != history.clips.count { save() }
        }
        // Idle ticks only read the pasteboard counter. Resolve source metadata and
        // exclusions only when there is actually a new copy to inspect.
        guard clipboard.hasChanges else { return }
        lastClipboardActivity = Date()
        let app = NSWorkspace.shared.frontmostApplication
        let ignored = Set(excluded).union(ClipboardCodec.defaultExclusions).union([
            Bundle.main.bundleIdentifier ?? "app.stash.clipboard"
        ])
        guard
            let clip = clipboard.read(
                sourceName: app?.localizedName ?? "Unknown app", sourceBundle: app?.bundleIdentifier ?? "",
                sourceTitle: paused || !rememberSourceDetails || ignored.contains(app?.bundleIdentifier ?? "")
                    ? nil : FocusedWindow.title(of: app),
                excluded: ignored, paused: paused)
        else { return }
        var captured = clip
        if !rememberSourceDetails { captured.sourceURL = nil }
        history.insert(captured, limit: historyLimit)
        save()
        if selection == nil { selection = results.first?.id }
    }
    func expire() {
        guard retention > 0 else { return }
        let cutoff = Date().addingTimeInterval(-Double(retention) * 86400)
        // Avoid publishing an unchanged History, which redraws the entire view.
        guard history.clips.contains(where: { !$0.pinned && $0.createdAt < cutoff }) else { return }
        history.expire(days: retention)
    }
    func save(immediately: Bool = false) {
        guard !demo, !historyLoadFailed else { return }
        // Session-only capture does not repeatedly rewrite an empty history file.
        guard !memoryOnly || immediately else { return }
        writer.submit(memoryOnly ? History() : history, immediately: immediately)
    }
    func terminate() {
        monitoring.stop()
        screenshots.stop()
        screenshotGeneration = UUID()
        writer.flush()
    }
    func selectFilter(_ kind: ClipKind?, pinned: Bool = false) {
        closeActions()
        previewOpen = false
        if promptsActive { query = "" }
        promptsActive = false
        category = kind
        pinnedOnly = pinned
        selection = results.first?.id
    }
    func reconcileSelection() {
        if !results.contains(where: { $0.id == selection }) { selection = results.first?.id }
    }
    func move(_ offset: Int) {
        let list = results
        guard !list.isEmpty else { return }

        let index = list.firstIndex { $0.id == selected?.id } ?? 0

        selection = list[max(0, min(list.count - 1, index + offset))].id
    }
    func togglePin(_ clip: Clip) {
        guard let i = history.clips.firstIndex(where: { $0.id == clip.id }) else { return }

        history.clips[i].pinned.toggle()
        let pinned = history.clips[i].pinned
        history.enforceLimits()

        reconcileSelection()
        save()
        message(pinned ? "Pinned to your collection" : "Unpinned")
    }
    func remove(_ clip: Clip) {
        deletedClip = clip
        canUndoDelete = true
        previewOpen = false
        history.clips.removeAll { $0.id == clip.id }
        reconcileSelection()
        save()
        message("Clip deleted")
    }
    func undoDelete() {
        guard let clip = deletedClip else { return }
        history.insert(clip, limit: historyLimit)
        selection = clip.id
        deletedClip = nil
        canUndoDelete = false
        save()

        message("Clip restored")
    }
    func cycleFilter(_ offset: Int) {
        let choices: [(kind: ClipKind?, pinned: Bool, prompts: Bool)] = [
            (nil, false, false), (nil, true, false), (.text, false, false), (.link, false, false),
            (.screenshot, false, false), (nil, false, true), (.image, false, false),
            (.file, false, false), (.email, false, false), (.color, false, false), (.video, false, false),
        ]
        let index =
            choices.firstIndex {
                $0.prompts == promptsActive
                    && (promptsActive || ($0.kind == category && $0.pinned == pinnedOnly))
            } ?? 0
        let next = choices[(index + offset + choices.count) % choices.count]
        // Key repeats can arrive faster than the category spring settles.
        // Apply the entire keyboard change in one nonanimated transaction so
        // the pill, result list, and preview state reflect this key immediately.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if next.prompts { openPrompts() } else { selectFilter(next.kind, pinned: next.pinned) }
        }
    }
    func clearHistory() {
        history.clips.removeAll { !$0.pinned }
        reconcileSelection()
        save()

        message("History cleared. Pinned clips kept.")
    }
    /// Counts a clip brought back from history toward the share card, then decides
    /// whether to show it the next time the palette opens.
    func recordRecall(_ clip: Clip) {
        guard !demo, let position = history.clips.firstIndex(where: { $0.id == clip.id }) else { return }
        sharePrompt.recordRecall(position: position)
    }
    func refreshSharePrompt() {
        showSharePrompt =
            (demo && CommandLine.arguments.contains("--share-prompt")) || (!demo && sharePrompt.shouldShow())
    }
    static let shareURL = URL(string: "https://heystash.io/?ref=share")!
    static let shareText = "I’ve been using Stash, a free clipboard manager for Mac. It’s great:"
    /// Keeps the card (and the view the menu points at) on screen until the share
    /// menu closes; removing it while the menu opens breaks both.
    private var shareDelegate: ShareMenuDelegate?
    func shareStash(from view: NSView?) {
        showShareMenu(from: view) { [weak self] shared in if shared { self?.finishSharePrompt() } }
    }
    /// The share menu used by the card, the menu bar and Settings, with Copy Link first.
    func showShareMenu(from view: NSView?, onDone: ((Bool) -> Void)? = nil) {
        guard let view, view.window != nil else { return }
        let picker = NSSharingServicePicker(items: [Self.shareText, Self.shareURL])
        let delegate = ShareMenuDelegate(extra: [copyLinkService()]) { [weak self] shared in
            onDone?(shared)
            self?.shareDelegate = nil
        }
        shareDelegate = delegate
        picker.delegate = delegate
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
    /// "Copy Link" at the top of the share menu.
    func copyLinkService() -> NSSharingService {
        NSSharingService(
            title: "Copy Link", image: NSImage(systemSymbolName: "link", accessibilityDescription: nil)!,
            alternateImage: nil
        ) { [weak self] in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(Self.shareURL.absoluteString, forType: .string)
            // Stash's own link shouldn't land in this person's history.
            self?.clipboard.skipCurrentChange()
            self?.message("Link copied")
        }
    }
    func starStash() {
        NSWorkspace.shared.open(URL(string: "https://github.com/AugmentedMode/Stash")!)
        finishSharePrompt()
    }
    func finishSharePrompt() {
        if !demo { sharePrompt.done() }
        showSharePrompt = false
    }
    func snoozeSharePrompt() {
        if !demo { sharePrompt.later() }
        showSharePrompt = false
    }
    @discardableResult func copy(_ clip: Clip, plain: Bool = false) -> Bool {
        if !plain, clip.fileURLs.contains(where: { !FileManager.default.fileExists(atPath: $0.path) }) {
            message("The original file was moved or deleted. Copy it again from Finder.")
            return false
        }
        guard ClipboardCodec.restore(clip, to: .general, plainText: plain) else {
            message("This clip couldn’t be copied")
            return false
        }
        recordRecall(clip)
        clipboard.skipCurrentChange()
        lastClipboardActivity = Date()
        message(plain ? "Copied as plain text" : "Copied to clipboard")
        return true
    }
    func paste(_ clip: Clip, plain: Bool = false) { onPaste?(clip, plain) }
    func message(_ text: String) {
        if text != "Clip deleted" {
            canUndoDelete = false
            deletedClip = nil
        }
        toast = text

        toastID = UUID()
        let id = toastID

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.toastID == id {
                self?.toast = nil
                self?.canUndoDelete = false
                self?.deletedClip = nil
            }
        }
    }
    func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an app to exclude"

        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false

        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else {
            return
        }
        if !excluded.contains(id) { excluded.append(id) }
    }
    var historyFileSize: Int64? {
        guard !memoryOnly else { return nil }
        return store.bytesOnDisk
    }
    static var version: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "Development build" }
        return "Version \(short)"
    }
}

/// Adds Stash's own items to the share menu and reports whether the person picked one.
final class ShareMenuDelegate: NSObject, NSSharingServicePickerDelegate {
    private let extra: [NSSharingService]
    private let done: (Bool) -> Void
    init(extra: [NSSharingService], done: @escaping (Bool) -> Void) {
        self.extra = extra
        self.done = done
    }
    func sharingServicePicker(
        _ picker: NSSharingServicePicker, sharingServicesForItems items: [Any],
        proposedSharingServices proposed: [NSSharingService]
    ) -> [NSSharingService] { extra + proposed }
    func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        DispatchQueue.main.async { self.done(service != nil) }
    }
}
