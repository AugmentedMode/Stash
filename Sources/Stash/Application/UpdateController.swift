import AppKit
import Combine
import Sparkle

/// Sparkle-backed update checks. Fetching the signed update feed from GitHub is the only
/// network request Stash makes; Sparkle's anonymous system profile stays off.
///
/// Stash lives in the menu bar, so scheduled checks never pop a window over the user's
/// work. A found update shows as a quiet badge in the palette until the user opens it.
final class UpdateController: NSObject, ObservableObject, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
    /// False in preview, QA and unbundled development builds, which must never update themselves.
    let isAvailable: Bool
    @Published private(set) var availableVersion: String?
    @Published private(set) var canCheck = false
    @Published private(set) var lastChecked: Date?
    @Published var checksAutomatically = false {
        didSet {
            guard let updater, updater.automaticallyChecksForUpdates != checksAutomatically else { return }
            updater.automaticallyChecksForUpdates = checksAutomatically
        }
    }
    @Published var installsAutomatically = false {
        didSet {
            guard let updater, updater.automaticallyDownloadsUpdates != installsAutomatically else { return }
            updater.automaticallyDownloadsUpdates = installsAutomatically
        }
    }
    /// Lets the palette get out of the way before Sparkle shows its window.
    var willShowUpdateWindow: (() -> Void)?
    private var controller: SPUStandardUpdaterController?
    private var updater: SPUUpdater? { controller?.updater }
    private var observations: [NSKeyValueObservation] = []

    init(enabled: Bool) {
        isAvailable =
            enabled && Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        super.init()
        guard isAvailable else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        self.controller = controller
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                DispatchQueue.main.async { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
                DispatchQueue.main.async { self?.lastChecked = updater.lastUpdateCheckDate }
            },
            updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) {
                [weak self] updater, _ in
                DispatchQueue.main.async { self?.checksAutomatically = updater.automaticallyChecksForUpdates }
            },
            updater.observe(\.automaticallyDownloadsUpdates, options: [.initial, .new]) {
                [weak self] updater, _ in
                DispatchQueue.main.async {
                    self?.installsAutomatically = updater.automaticallyDownloadsUpdates
                }
            },
        ]
    }

    func checkForUpdates() {
        guard let updater, updater.canCheckForUpdates else { return }
        willShowUpdateWindow?()
        NSApp.activate(ignoringOtherApps: true)
        updater.checkForUpdates()
    }

    // MARK: SPUStandardUserDriverDelegate

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Only interrupt when Stash itself is in front; otherwise show the badge.
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        DispatchQueue.main.async { self.availableVersion = update.displayVersionString }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        DispatchQueue.main.async { self.availableVersion = nil }
    }

    func standardUserDriverWillFinishUpdateSession() {
        DispatchQueue.main.async { self.availableVersion = nil }
    }
}
