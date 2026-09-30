import SwiftUI
import Combine
import AppKit
import ApplicationServices
import StashCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab = SettingsTab.general
    @State private var confirmClear = false
    @State private var confirmMemory = false
    @State private var trusted = AXIsProcessTrusted()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var openAtLogin = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.needsApproval
    @State private var loginError: String?
    @Namespace private var tabPill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General", history = "History", screenshots = "Screenshots", privacy = "Privacy"
        case about = "About"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .history: return "clock.arrow.circlepath"
            case .screenshots: return "camera.viewfinder"
            case .privacy: return "hand.raised"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.line).frame(height: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch tab {
                    case .general: general
                    case .history: history
                    case .screenshots: screenshots
                    case .privacy: privacy
                    case .about: about
                    }
                }.padding(.horizontal, 22).padding(.vertical, 20).frame(
                    maxWidth: .infinity, alignment: .leading)
            }.id(tab).scrollIndicators(.automatic)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark).tint(.accent)
        .onAppear {
            if model.screenshotSettingsRequested { tab = .screenshots }
            if let name = model.requestedSettingsTab,
                let requested = SettingsTab.allCases.first(where: {
                    $0.rawValue.lowercased() == name.lowercased()
                })
            {
                tab = requested
            }
            model.requestedSettingsTab = nil
        }
        .onDisappear {
            model.screenshotSettingsRequested = false
            model.recordingShortcut = false
        }
        .onReceive(refresh) { _ in refreshSystemState() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) {
            _ in
            refreshSystemState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) {
            _ in
            model.recordingShortcut = false
        }
        .alert("Clear unpinned history?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { model.clearHistory() }
        } message: {
            Text("This removes unpinned clips from Stash. Your pinned clips and current clipboard are kept.")
        }
        .alert("Use session-only history?", isPresented: $confirmMemory) {
            Button("Cancel", role: .cancel) {}
            Button("Use session only", role: .destructive) { model.memoryOnly = true }
        } message: {
            Text(
                "The saved history on disk will be cleared. Current clips stay available until Stash quits, including pinned clips."
            )
        }
    }

    private func refreshSystemState() {
        trusted = AXIsProcessTrusted()
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        openAtLogin = LoginItem.isEnabled
        loginNeedsApproval = LoginItem.needsApproval
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    model.settingsOpen = false
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.muted).frame(width: 28, height: 28)
                        .background(.white.opacity(0.06), in: Circle())
                }.buttonStyle(.plain).help("Back to Stash · esc").accessibilityLabel("Back to Stash")
                Text("Settings").font(.system(size: 20, weight: .medium)).tracking(-0.4).foregroundStyle(
                    .white)
                Spacer()
                Label("Saved automatically", systemImage: "checkmark.circle")
                    .font(.system(size: 11)).foregroundStyle(Color.quiet)
            }
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { item in tabButton(item) }
                Spacer(minLength: 0)
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.18, bounce: 0.12), value: tab)
        }.padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 14)
    }

    private func tabButton(_ item: SettingsTab) -> some View {
        let active = tab == item
        return Button {
            tab = item
        } label: {
            HStack(spacing: 5) {
                Image(systemName: item.symbol).font(.system(size: 11, weight: .medium))
                Text(item.rawValue).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(active ? Color.white : Color.muted)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background {
                if active {
                    Capsule().fill(Color.accent.opacity(0.16))
                        .overlay(Capsule().strokeBorder(Color.accent.opacity(0.16), lineWidth: 0.5))
                        .matchedGeometryEffect(id: "tab", in: tabPill)
                }
            }
            .contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityLabel(item.rawValue)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text("Stash · \(AppModel.version)").font(.system(size: 11)).foregroundStyle(Color.quiet)
            Spacer()
            Button {
                model.settingsOpen = false
            } label: {
                hint("esc", "Back")
            }.buttonStyle(.plain).help("Back to your clips")
            Button {
                model.hidePanel?()
            } label: {
                hint("⌘W", "Close")
            }.buttonStyle(.plain).help("Close Stash · or press \(model.shortcut.display)")
        }.padding(.horizontal, 20).padding(.vertical, 12)
            .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 0.5) }
    }

    private func hint(_ key: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Text(key).font(.system(size: 11, design: .monospaced)).padding(.horizontal, 5).padding(
                .vertical, 3
            )
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 5))
            Text(title).font(.system(size: 11))
        }.foregroundStyle(Color.quiet)
    }

    // MARK: - General

    @ViewBuilder private var general: some View {
        SettingsSection(title: "Shortcut") {
            SettingsRow(
                icon: "command", title: "Open Stash",
                subtitle: model.recordingShortcut
                    ? "Press the new shortcut. Esc cancels, Delete restores ⌘⇧V."
                    : "Show or hide Stash from any app."
            ) {
                ShortcutRecorder(model: model)
            }
            if let issue = model.shortcutIssue {
                SettingsDivider()
                SettingsRow(icon: "exclamationmark.triangle", tint: .settingsOrange, title: issue)
            }
        }
        SettingsSection(title: "Pasting") {
            SettingsRow(
                icon: "return", tint: .settingsBlue, title: "Quick Paste",
                subtitle: trusted
                    ? "Return pastes the clip straight into the app you were using."
                    : "Allow Accessibility access to paste with Return. Until then, Stash copies the clip and you press ⌘V."
            ) {
                if trusted {
                    StatusBadge(text: "On", color: .settingsGreen)
                } else {
                    Button("Enable…", action: requestAccessibility).buttonStyle(
                        SettingsButtonStyle(kind: .prominent))
                }
            }
        }
        SettingsSection(title: "Startup", footnote: loginError) {
            SettingsRow(
                icon: "power", tint: .settingsGreen, title: "Open at login",
                subtitle: loginNeedsApproval
                    ? "Waiting for approval in System Settings → General → Login Items."
                    : "Start Stash quietly in the menu bar when you log in."
            ) {
                if loginNeedsApproval {
                    Button("Open Settings…") { LoginItem.openSystemSettings() }.buttonStyle(
                        SettingsButtonStyle())
                } else {
                    SettingsSwitch(
                        title: "Open at login",
                        isOn: Binding(get: { openAtLogin }, set: setOpenAtLogin))
                }
            }
        }
    }

    private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    private func setOpenAtLogin(_ value: Bool) {
        do {
            try LoginItem.set(value)
            loginError = nil
        } catch {
            loginError =
                Bundle.main.bundleIdentifier == nil
                ? "Open at login works from the installed Stash app."
                : "macOS didn’t allow this change. Try again from System Settings → General → Login Items."
        }
        refreshSystemState()
    }

    // MARK: - History

    @ViewBuilder private var history: some View {
        SettingsSection(title: "Capture") {
            SettingsRow(
                icon: model.paused ? "pause.fill" : "record.circle",
                tint: model.paused ? .settingsOrange : .settingsGreen,
                title: "Pause capture",
                subtitle: model.paused
                    ? "New copies are ignored until you resume."
                    : "Stash is saving new copies as you make them."
            ) {
                SettingsSwitch(title: "Pause capture", isOn: $model.paused)
            }
        }
        SettingsSection(title: "Storage", footnote: "Pinned clips are never removed automatically.") {
            SettingsRow(icon: "calendar", tint: .settingsBlue, title: "Keep unpinned clips for") {
                SettingsMenu(
                    title: "History retention", selection: $model.retention,
                    options: [
                        ("1 day", 1), ("7 days", 7), ("30 days", 30), ("90 days", 90), ("1 year", 365),
                        ("Forever", 0),
                    ])
            }
            SettingsDivider()
            SettingsRow(
                icon: "square.stack.3d.up", tint: .settingsBlue, title: "Maximum clips",
                subtitle: "Oldest unpinned clips make room for new ones."
            ) {
                SettingsMenu(
                    title: "Maximum clips", selection: $model.historyLimit,
                    options: [("100", 100), ("250", 250), ("500", 500), ("1,000", 1000), ("2,500", 2500)])
            }
        }
        SettingsSection(title: "Your history") {
            HStack(spacing: 0) {
                stat("\(model.history.clips.count)", "clips")
                statDivider
                stat("\(model.history.clips.filter(\.pinned).count)", "pinned")
                statDivider
                stat(
                    model.memoryOnly
                        ? "Memory"
                        : model.historyFileSize.map {
                            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
                        } ?? "—",
                    model.memoryOnly ? "session only" : "on disk")
            }.padding(.vertical, 14)
            Rectangle().fill(Color.line).frame(height: 0.5)
            SettingsRow(
                icon: "trash", tint: .settingsPink, title: "Clear unpinned history",
                subtitle: "Pinned clips stay right where they are."
            ) {
                Button("Clear…", role: .destructive) { confirmClear = true }
                    .buttonStyle(SettingsButtonStyle(kind: .destructive))
                    .disabled(!model.history.clips.contains { !$0.pinned })
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 19, weight: .medium)).monospacedDigit().foregroundStyle(
                .white.opacity(0.92))
            Text(label).font(.system(size: 11)).foregroundStyle(Color.quiet)
        }.frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
    private var statDivider: some View { Rectangle().fill(Color.line).frame(width: 0.5, height: 30) }

    // MARK: - Screenshots

    @ViewBuilder private var screenshots: some View {
        SettingsSection(title: "Collection") {
            SettingsRow(
                icon: "camera.viewfinder", tint: .settingsTeal, title: "Collect saved screenshots",
                subtitle: "Add new macOS screenshots to your history as they’re saved."
            ) {
                SettingsSwitch(title: "Collect saved screenshots", isOn: $model.screenshotsEnabled)
            }
            if model.screenshotsEnabled {
                SettingsDivider()
                SettingsRow(
                    icon: "doc.on.clipboard", tint: .settingsTeal, title: "Copy new screenshots",
                    subtitle: model.screenshotAutoCopy
                        ? "Take a screenshot, then press ⌘V. A newer copy always wins."
                        : "Screenshots go into history. Your clipboard stays as it is."
                ) {
                    SettingsSwitch(
                        title: "Copy new screenshots to clipboard", isOn: $model.screenshotAutoCopy)
                }
            }
        }
        SettingsSection(
            title: "Folder",
            footnote:
                "Match the folder in ⇧⌘5 → Options → Save to. Only new screenshots are collected, and they stay in history if you delete the originals. App exclusions don’t apply to screenshots."
        ) {
            SettingsRow(
                icon: "folder", tint: .settingsBlue, title: folderName,
                subtitle: (model.screenshotFolder as NSString).abbreviatingWithTildeInPath
            ) {
                HStack(spacing: 6) {
                    if let system = systemScreenshotFolder, system != model.screenshotFolder {
                        Button("Use macOS folder") { model.screenshotFolder = system }
                            .buttonStyle(SettingsButtonStyle())
                    }
                    Button("Choose…") { model.chooseScreenshotFolder() }.buttonStyle(SettingsButtonStyle())
                }
            }
            SettingsDivider()
            SettingsRow(
                icon: model.screenshotIssue == nil
                    ? "dot.radiowaves.left.and.right" : "exclamationmark.triangle",
                tint: model.screenshotIssue == nil ? .settingsGreen : .settingsOrange,
                title: model.screenshotStatus)
        }
    }

    private var folderName: String {
        FileManager.default.displayName(atPath: model.screenshotFolder)
    }
    private var systemScreenshotFolder: String? {
        UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location").map {
            ($0 as NSString).expandingTildeInPath
        }
    }

    // MARK: - Privacy

    @ViewBuilder private var privacy: some View {
        SettingsSection(title: "Storage") {
            SettingsRow(
                icon: "memorychip", tint: .settingsBlue, title: "Session-only history",
                subtitle: model.memoryOnly
                    ? "Nothing is saved to disk. All clips, including pins, are discarded when Stash quits."
                    : "History is saved on this Mac only. Copies over 20 MB are skipped."
            ) {
                SettingsSwitch(
                    title: "Session-only history",
                    isOn: Binding(
                        get: { model.memoryOnly },
                        set: { value in
                            if value { confirmMemory = true } else { model.memoryOnly = false }
                        }))
            }
            SettingsDivider()
            SettingsRow(
                icon: "location", tint: .settingsBlue, title: "Remember where clips came from",
                subtitle: model.rememberSourceDetails
                    ? "Saves the window title and web page with each clip so you can go back to it."
                    : "Only the app name is saved. Turning this off erased saved window titles and pages."
            ) {
                SettingsSwitch(title: "Remember where clips came from", isOn: $model.rememberSourceDetails)
            }
        }
        SettingsSection(
            title: "Excluded apps",
            footnote:
                "Copies from these apps never enter your history. Copies that apps mark as secret are always skipped."
        ) {
            ForEach(customExclusions, id: \.self) { id in
                ExcludedAppRow(bundleID: id) { model.excluded.removeAll { $0 == id } }
                SettingsDivider()
            }
            SettingsRow(
                icon: "key.fill", tint: .settingsOrange, title: "Password managers",
                subtitle: passwordManagerSummary
            ) {
                Text("Always").font(.system(size: 11)).foregroundStyle(Color.quiet)
            }
            SettingsDivider()
            Button {
                model.addExcludedApp()
            } label: {
                HStack(spacing: 12) {
                    SettingsIcon(symbol: "plus", tint: .accent)
                    Text("Add app…").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.accent)
                    Spacer()
                }.padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        SettingsSection(title: "Promise") {
            SettingsRow(
                icon: "lock.shield", tint: .settingsGreen, title: "Your clips stay on this Mac",
                subtitle: "No account, no sync, no analytics. Stash never sends your clipboard anywhere.")
        }
    }

    private var customExclusions: [String] {
        model.excluded.filter { !ClipboardCodec.defaultExclusions.contains($0) }
    }
    private var passwordManagerSummary: String {
        let installed = ClipboardCodec.defaultExclusions.compactMap(AppInfo.name(for:)).sorted()
        return installed.isEmpty
            ? "1Password, Bitwarden, Passwords and others" : installed.joined(separator: ", ")
    }

    // MARK: - About

    @ViewBuilder private var about: some View {
        HStack(spacing: 16) {
            Group {
                if Bundle.main.bundleURL.pathExtension == "app" {
                    Image(nsImage: NSApp.applicationIconImage).resizable()
                } else {
                    Image(systemName: "square.stack.3d.up").font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                }
            }.frame(width: 60, height: 60).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Stash").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                Text(AppModel.version).font(.system(size: 12)).foregroundStyle(Color.muted)
                Text("A little space for everything you copy.").font(.system(size: 12)).foregroundStyle(
                    Color.quiet)
            }
            Spacer()
        }.padding(.horizontal, 4)
        SettingsSection(title: "Help") {
            linkRow("sparkles", "What’s new", "Release notes and downloads", "releases")
            SettingsDivider()
            linkRow("ladybug", "Report a bug", "Tell us what went wrong", "issues/new/choose")
            SettingsDivider()
            linkRow("chevron.left.forwardslash.chevron.right", "Source code", "Stash is open source", "")
        }
        SettingsSection(
            title: "Energy",
            footnote:
                "Capture stops while paused, while the display sleeps, and when your session is inactive. Stash checks the clipboard every 0.6 seconds, or every 1.2 seconds in Low Power Mode."
        ) {
            SettingsRow(
                icon: "leaf", tint: .settingsGreen,
                title: lowPower ? "Low Power Mode" : "Adaptive energy use",
                subtitle: lowPower
                    ? "Checking less often to save battery." : "Checking lightly in the background.")
        }
        SettingsSection(title: "Stash") {
            SettingsRow(
                icon: "power", tint: .settingsPink, title: "Quit Stash",
                subtitle: "Your history is saved first."
            ) {
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(SettingsButtonStyle())
            }
        }
    }

    private func linkRow(_ icon: String, _ title: String, _ subtitle: String, _ path: String) -> some View {
        Button {
            NSWorkspace.shared.open(URL(string: "https://github.com/AugmentedMode/Stash/\(path)")!)
        } label: {
            SettingsRow(icon: icon, tint: .accent, title: title, subtitle: subtitle) {
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.quiet)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

/// Click to record a new global shortcut; the app delegate captures the key press.
struct ShortcutRecorder: View {
    @ObservedObject var model: AppModel
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 6) {
            if !model.recordingShortcut && model.shortcut != .standard {
                Button {
                    model.shortcut = .standard
                } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.quiet)
                }.buttonStyle(.plain).help("Restore ⌘⇧V").accessibilityLabel("Restore default shortcut")
            }
            Button {
                model.recordingShortcut.toggle()
            } label: {
                HStack(spacing: 4) {
                    if model.recordingShortcut {
                        Text("Type shortcut…").font(.system(size: 12, weight: .medium)).foregroundStyle(
                            Color.accent
                        )
                        .opacity(pulse ? 0.55 : 1)
                    } else {
                        ForEach(model.shortcut.symbols, id: \.self) { symbol in
                            Text(symbol).font(.system(size: 12, weight: .medium, design: .rounded))
                                .frame(minWidth: 18).padding(.horizontal, 3).padding(.vertical, 3)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                .foregroundStyle(.white.opacity(0.9)).padding(.horizontal, 6).padding(.vertical, 4)
                .frame(minWidth: 96)
                .background(
                    model.recordingShortcut ? Color.accent.opacity(0.1) : .white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(
                        model.recordingShortcut ? Color.accent.opacity(0.6) : Color.white.opacity(0.08),
                        lineWidth: model.recordingShortcut ? 1 : 0.5)
                )
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
                .help(model.recordingShortcut ? "Press a new shortcut, or Esc to cancel" : "Click to change")
                .accessibilityLabel(
                    model.recordingShortcut
                        ? "Recording shortcut" : "Shortcut \(model.shortcut.display). Change")
        }
        .onChange(of: model.recordingShortcut) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true }
            } else {
                pulse = false
            }
        }
    }
}

struct ExcludedAppRow: View {
    let bundleID: String
    let remove: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = AppInfo.icon(for: bundleID) {
                    Image(nsImage: icon).resizable()
                } else {
                    SettingsIcon(symbol: "app.dashed", tint: .muted)
                }
            }.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(AppInfo.name(for: bundleID) ?? bundleID).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                Text(bundleID).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.quiet)
                    .lineLimit(1)
            }
            Spacer()
            Button("Remove", action: remove).buttonStyle(SettingsButtonStyle())
                .accessibilityLabel("Stop excluding \(AppInfo.name(for: bundleID) ?? bundleID)")
        }.padding(.horizontal, 14).padding(.vertical, 10)
    }
}

enum AppInfo {
    static func url(for bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
    static func name(for bundleID: String) -> String? {
        guard let url = url(for: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
    static func icon(for bundleID: String) -> NSImage? {
        url(for: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
    }
}
