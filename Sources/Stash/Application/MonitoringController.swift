import AppKit
import StashCore

/// Main-thread owner of polling and system notifications. Low Power Mode only
/// changes the polling timer; it must not restart the screenshot folder watcher.
final class MonitoringController {
    private var timer: Timer?
    private var powerObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var suspensions = Set<String>()
    private var paused = false
    private let powerChanged: (Bool) -> Void
    private let poll: () -> Void
    private let suspensionChanged: () -> Void
    private let willSleep: () -> Void

    var isSuspended: Bool { !suspensions.isEmpty }

    init(
        powerChanged: @escaping (Bool) -> Void, poll: @escaping () -> Void,
        suspensionChanged: @escaping () -> Void, willSleep: @escaping () -> Void
    ) {
        self.powerChanged = powerChanged
        self.poll = poll
        self.suspensionChanged = suspensionChanged
        self.willSleep = willSleep
    }

    func start(paused: Bool) {
        self.paused = paused
        if powerObserver == nil {
            powerObserver = NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
            ) { [weak self] _ in self?.configureTimer() }
            let center = NSWorkspace.shared.notificationCenter
            let events: [(Notification.Name, String, Bool)] = [
                (NSWorkspace.willSleepNotification, "sleep", true),
                (NSWorkspace.didWakeNotification, "sleep", false),
                (NSWorkspace.screensDidSleepNotification, "display", true),
                (NSWorkspace.screensDidWakeNotification, "display", false),
                (NSWorkspace.sessionDidResignActiveNotification, "session", true),
                (NSWorkspace.sessionDidBecomeActiveNotification, "session", false),
            ]
            for (name, reason, suspend) in events {
                workspaceObservers.append(
                    center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                        guard let self else { return }
                        if suspend {
                            self.suspensions.insert(reason)
                        } else {
                            self.suspensions.remove(reason)
                        }
                        self.configureTimer()
                        self.suspensionChanged()
                        if reason == "sleep", suspend { self.willSleep() }
                    })
            }
        }
        configureTimer()
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        guard
            let interval = ClipboardPollingPolicy.interval(
                paused: paused, suspended: isSuspended,
                lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
            )
        else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = interval * 0.25
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) }
        powerObserver = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        suspensions.removeAll()
    }

    deinit { stop() }
}
