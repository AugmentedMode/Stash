import AppKit
import SwiftUI
import StashCore

final class AppModel: ObservableObject {
    @Published var history = History() { didSet { cachedResults = nil } }
    @Published var query = "" { didSet { cachedResults = nil } }
    @Published var category: ClipKind? { didSet { cachedResults = nil } }
    @Published var pinnedOnly = false { didSet { cachedResults = nil } }
    @Published var selection: UUID?
    @Published var paused = false { didSet { if oldValue != paused { configureMonitoring(skipCurrent: true) } } }
    @Published private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var destinationName = "previous app"
    @Published var quickPasteReady = false
    @Published var shortcutIssue: String?
    var screenshotSettingsRequested = false
    @Published var settingsOpen = false
    @Published var previewOpen = false
    @Published var canUndoDelete = false
    private var deletedClip: Clip?
    @Published var toast: String?
    @Published var error: String?
    @Published var started: Bool
    @Published var retention: Int { didSet { defaults.set(retention, forKey: "retention"); expire(); save() } }
    @Published var memoryOnly: Bool { didSet { defaults.set(memoryOnly, forKey: "memoryOnly"); save(immediately: true) } }
    @Published var excluded: [String] { didSet { defaults.set(excluded, forKey: "excluded") } }
    @Published var screenshotsEnabled: Bool { didSet { defaults.set(screenshotsEnabled, forKey: "screenshotsEnabled"); configureScreenshots() } }
    @Published var screenshotAutoCopy: Bool { didSet { defaults.set(screenshotAutoCopy, forKey: "screenshotAutoCopy") } }
    @Published var screenshotFolder: String { didSet { defaults.set(screenshotFolder, forKey: "screenshotFolder"); configureScreenshots() } }
    @Published var screenshotIssue: String?
    private let screenshots = ScreenshotObserver()
    private var screenshotGeneration = UUID()
    private var lastClipboardActivity = Date.distantPast
    var screenshotStatus: String {
        if demo { return "Preview mode · capture is off" }
        if !screenshotsEnabled { return "Off · your clipboard stays as it is" }
        if paused || !suspensions.isEmpty { return "Paused · resumes with clipboard capture" }
        return screenshotIssue ?? "Watching for new screenshots"
    }
    func chooseScreenshotFolder() {
        let panel = NSOpenPanel(); panel.title = "Choose your screenshot save folder"
        panel.message = "Choose the same folder as Screenshot → Options → Save to. Only new macOS screenshots will be collected."
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: screenshotFolder)
        if panel.runModal() == .OK, let url = panel.url { screenshotFolder = url.path }
    }
    private func configureScreenshots() {
        screenshots.stop(); screenshotGeneration = UUID(); screenshotIssue = nil
        guard started, !demo, screenshotsEnabled, !paused, suspensions.isEmpty else { return }
        let generation = screenshotGeneration
        screenshots.start(folder: URL(fileURLWithPath: screenshotFolder), receive: { [weak self] clip in
            guard let self, self.screenshotGeneration == generation else { return }
            self.history.insert(clip); self.save()
            if self.selection == nil { self.selection = self.results.first?.id }
            // Do not overwrite a copy made while this image was being prepared.
            if self.screenshotAutoCopy && !self.clipboard.hasChanges && self.lastClipboardActivity < clip.createdAt {
                if ClipboardCodec.restore(clip, to: .general) { self.clipboard.skipCurrentChange(); self.message("Screenshot copied · ready to paste") }
            } else { self.message("Screenshot saved to history") }
        }, failure: { [weak self] in
            guard let self, self.screenshotGeneration == generation else { return }
            self.screenshotIssue = "Folder unavailable. Choose it again to restore access."
        })
    }
    let demo: Bool
    let defaults: UserDefaults
    let diskURL: URL
    var showPanel: (() -> Void)?
    var hidePanel: (() -> Void)?
    var onPaste: ((Clip, Bool) -> Void)?
    private var timer: Timer?
    private let clipboard = ClipboardObserver()
    private lazy var writer = HistoryWriter(write: { [diskURL] snapshot in
        try HistoryDisk.save(snapshot, to: diskURL)
    }, onError: { [weak self] _ in
        DispatchQueue.main.async { self?.error = "History couldn’t be saved. New clips are available for this session only." }
    })
    private var cachedResults: [Clip]?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var powerObserver: NSObjectProtocol?
    private var suspensions: Set<String> = []
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
        defaults = demo ? UserDefaults(suiteName: "app.stash.preview")! : .standard
        diskURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Stash/history.json")
        started = demo || defaults.bool(forKey: "started")
        retention = defaults.object(forKey: "retention") as? Int ?? 30
        memoryOnly = defaults.bool(forKey: "memoryOnly")
        screenshotsEnabled = defaults.bool(forKey: "screenshotsEnabled")
        screenshotAutoCopy = defaults.object(forKey: "screenshotAutoCopy") as? Bool ?? true
        screenshotFolder = defaults.string(forKey: "screenshotFolder") ?? (UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location").map { ($0 as NSString).expandingTildeInPath }) ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
        excluded = defaults.stringArray(forKey: "excluded") ?? ClipboardCodec.defaultExclusions.sorted()
        if demo { history = Self.examples() } else if !memoryOnly {
            do { history = try HistoryDisk.load(from: diskURL) } catch { self.error = "Your saved history couldn’t be opened. It has been left untouched." }
        }
        expire(); selection = results.first?.id
        if started && !demo { startMonitoring() }
    }
    func start() { started = true; defaults.set(true, forKey: "started"); startMonitoring() }
    func startMonitoring() {
        guard !demo else { return }
        if powerObserver == nil {
            powerObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                self.configureMonitoring(skipCurrent: false)
            }
            let center = NSWorkspace.shared.notificationCenter
            let events: [(Notification.Name, String, Bool)] = [
                (NSWorkspace.willSleepNotification, "sleep", true),
                (NSWorkspace.didWakeNotification, "sleep", false),
                (NSWorkspace.screensDidSleepNotification, "display", true),
                (NSWorkspace.screensDidWakeNotification, "display", false),
                (NSWorkspace.sessionDidResignActiveNotification, "session", true),
                (NSWorkspace.sessionDidBecomeActiveNotification, "session", false)
            ]
            for (name, reason, suspend) in events {
                workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    if suspend { self.suspensions.insert(reason) } else { self.suspensions.remove(reason) }
                    self.configureMonitoring(skipCurrent: true)
                    if reason == "sleep", suspend { self.writer.flush() }
                })
            }
        }
        configureMonitoring(skipCurrent: true)
    }
    private func configureMonitoring(skipCurrent: Bool) {
        timer?.invalidate(); timer = nil
        configureScreenshots()
        guard !demo, started else { return }
        if skipCurrent { clipboard.skipCurrentChange() }
        guard let interval = ClipboardPollingPolicy.interval(paused: paused, suspended: !suspensions.isEmpty, lowPower: lowPower) else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.poll() }
        timer?.tolerance = interval * 0.25
    }
    func poll() {
        if Date() >= nextExpiry {
            nextExpiry = Date().addingTimeInterval(300)
            let count = history.clips.count; expire()
            if count != history.clips.count { save() }
        }
        // Idle ticks only read the pasteboard counter. Resolve source metadata and
        // exclusions only when there is actually a new copy to inspect.
        guard clipboard.hasChanges else { return }
        lastClipboardActivity = Date()
        let app = NSWorkspace.shared.frontmostApplication
        let ignored = Set(excluded).union(ClipboardCodec.defaultExclusions).union([Bundle.main.bundleIdentifier ?? "app.stash.clipboard"])
        guard let clip = clipboard.read(sourceName: app?.localizedName ?? "Unknown app", sourceBundle: app?.bundleIdentifier ?? "", excluded: ignored, paused: paused) else { return }
        history.insert(clip); save()
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
        guard !demo, error == nil else { return }
        // Session-only capture does not repeatedly rewrite an empty history file.
        guard !memoryOnly || immediately else { return }
        writer.submit(memoryOnly ? History() : history, immediately: immediately)
    }
    func terminate() {
        timer?.invalidate()
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        writer.flush()
    }
    func selectFilter(_ kind: ClipKind?, pinned: Bool = false) { previewOpen = false; category = kind; pinnedOnly = pinned; selection = results.first?.id }
    func reconcileSelection() { if !results.contains(where: { $0.id == selection }) { selection = results.first?.id } }
    func move(_ offset: Int) { let list = results; guard !list.isEmpty else { return }; let index = list.firstIndex { $0.id == selected?.id } ?? 0; selection = list[max(0, min(list.count - 1, index + offset))].id }
    func togglePin(_ clip: Clip) { guard let i = history.clips.firstIndex(where: { $0.id == clip.id }) else { return }; history.clips[i].pinned.toggle(); let pinned = history.clips[i].pinned; reconcileSelection(); save(); message(pinned ? "Pinned to your collection" : "Unpinned") }
    func remove(_ clip: Clip) {
        deletedClip = clip; canUndoDelete = true; previewOpen = false
        history.clips.removeAll { $0.id == clip.id }; reconcileSelection(); save(); message("Clip deleted")
    }
    func undoDelete() {
        guard let clip = deletedClip else { return }
        history.insert(clip); selection = clip.id; deletedClip = nil; canUndoDelete = false; save(); message("Clip restored")
    }
    func cycleFilter(_ offset: Int) {
        let choices: [(kind: ClipKind?, pinned: Bool)] = [(nil, false), (nil, true), (.text, false), (.link, false), (.screenshot, false), (.file, false), (.image, false), (.email, false), (.color, false), (.video, false)]
        let index = choices.firstIndex { $0.kind == category && $0.pinned == pinnedOnly } ?? 0
        let next = choices[(index + offset + choices.count) % choices.count]
        // Key repeats can arrive faster than the category spring settles.
        // Apply the entire keyboard change in one nonanimated transaction so
        // the pill, result list, and preview state reflect this key immediately.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            selectFilter(next.kind, pinned: next.pinned)
        }
    }
    func clearHistory() { history.clips.removeAll { !$0.pinned }; reconcileSelection(); save(); message("History cleared. Pinned clips kept.") }
    @discardableResult func copy(_ clip: Clip, plain: Bool = false) -> Bool {
        if !plain, clip.fileURLs.contains(where: { !FileManager.default.fileExists(atPath: $0.path) }) {
            message("The original file was moved or deleted. Copy it again from Finder.")
            return false
        }
        guard ClipboardCodec.restore(clip, to: .general, plainText: plain) else {
            message("This clip couldn’t be copied")
            return false
        }
        clipboard.skipCurrentChange(); lastClipboardActivity = Date()
        message(plain ? "Copied as plain text" : "Copied to clipboard")
        return true
    }
    func paste(_ clip: Clip, plain: Bool = false) { onPaste?(clip, plain) }
    func message(_ text: String) { if text != "Clip deleted" { canUndoDelete = false; deletedClip = nil }; toast = text; toastID = UUID(); let id = toastID; DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in if self?.toastID == id { self?.toast = nil; self?.canUndoDelete = false; self?.deletedClip = nil } } }
    func addExcludedApp() {
        let panel = NSOpenPanel(); panel.title = "Choose an app to exclude"; panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.canChooseDirectories = false; panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        if !excluded.contains(id) { excluded.append(id) }
    }
    static func examples() -> History {
        let now = Date()
        let seeds: [(ClipKind, String, String, Bool, TimeInterval)] = [
            (.text, "Good ideas deserve a place to land.\n\nStash is a little breathing room for your clipboard. Collect what matters, keep your flow, and find it again when you need it.", "Notes", true, -240),
            (.color, "#B7F46B", "Figma", true, -380),
            (.link, "https://app.notion.com/p/Design-system-notes-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link", "Slack", false, -420),
            (.text, "A quieter kind of productivity.\n\nLess switching. More making.\nOne small shortcut to keep everything moving.", "Notes", false, -900),
            (.email, "hello@example.com", "Mail", false, -1500),
            (.color, "#AFA2FF", "Figma", false, -2100),
            (.text, "let ideas = clipboard.collect()\nlet next = ideas.find(\"the good one\")\nnext.paste()", "Xcode", false, -3500),
            (.link, "https://github.com/swiftlang/swift/pull/123", "Safari", false, -90000),
            (.text, "Make room for the next good thing.", "Notes", false, -95000)
        ]
        return History(clips: seeds.map { Clip(createdAt: now.addingTimeInterval($0.4), sourceName: $0.2, kind: $0.0, text: $0.1, pinned: $0.3) })
    }
}
