import SwiftUI
import AppKit
import ApplicationServices

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var tab = SettingsTab.general
    private enum SettingsTab: String, CaseIterable {
        case general = "General", screenshots = "Screenshots", privacy = "Privacy"
    }
    @State private var confirmClear = false
    @State private var confirmMemory = false
    @State private var trusted = AXIsProcessTrusted()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button {
                        model.settingsOpen = false
                    } label: {
                        Label("Back to Stash", systemImage: "arrow.left")
                    }
                    .buttonStyle(.plain).foregroundStyle(Color.muted)
                    Spacer()
                    Text("Changes save automatically").font(.system(size: 11)).foregroundStyle(Color.quiet)
                }.font(.system(size: 12))
                Text("Settings").font(.system(size: 25, weight: .medium)).tracking(-0.6)
                Picker("Settings section", selection: $tab) {
                    ForEach(SettingsTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }.padding(22)
            Divider().overlay(Color.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if tab == .general {
                        generalSettings
                    }
                    if tab == .screenshots {
                        screenshotSettings
                    }
                    if tab == .general {
                        quickPasteAndEnergy
                    }
                    if tab == .privacy {
                        privacySettings
                    }
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            }.id(tab)
            Divider().overlay(Color.line)
            HStack {
                Text("Stash 1.0")
                Spacer()
                Button("Quit Stash") { NSApp.terminate(nil) }.buttonStyle(.plain)
            }.font(.system(size: 11)).foregroundStyle(Color.muted).padding(.horizontal, 22).padding(
                .vertical, 12)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas).preferredColorScheme(
            .dark
        ).tint(.accent)
            .onAppear { if model.screenshotSettingsRequested { tab = .screenshots } }
            .onDisappear { model.screenshotSettingsRequested = false }
            .onExitCommand { if !confirmClear && !confirmMemory { model.settingsOpen = false } }
            .onReceive(refresh) { _ in
                trusted = AXIsProcessTrusted()
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
            .alert("Clear unpinned history?", isPresented: $confirmClear) {
                Button("Cancel", role: .cancel) {}

                Button("Clear history", role: .destructive) { model.clearHistory() }
            } message: {
                Text(
                    "This removes unpinned clips from Stash. Your pinned clips and current clipboard are kept."
                )
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
    private var clipboardSettings: some View {
        Group {

            section("Clipboard history") {
                settingToggle("Pause capture", isOn: $model.paused)
                Divider().overlay(Color.line)
                HStack {
                    Text("Keep unpinned clips for")
                    Spacer()

                    Picker("History retention", selection: $model.retention) {
                        Text("1 day").tag(1)
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)

                        Text("90 days").tag(90)
                        Text("Forever").tag(0)
                    }.labelsHidden().frame(width: 115)
                }
            }

        }
    }

    private var screenshotSettings: some View {
        Group {

            section("Screenshot collection") {
                Toggle("Collect saved screenshots", isOn: $model.screenshotsEnabled).toggleStyle(
                    .switch)
                if model.screenshotsEnabled {
                    Toggle("Copy new screenshots to clipboard", isOn: $model.screenshotAutoCopy)
                        .toggleStyle(.switch)
                    Text(
                        model.screenshotAutoCopy
                            ? "Take a screenshot, then press ⌘V after it saves. A newer clipboard copy takes priority."
                            : "Screenshots go into history. Your clipboard stays as it is."
                    )
                    .font(.system(size: 12)).foregroundStyle(Color.muted)
                }
                Divider().overlay(Color.line)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screenshot save folder").font(.system(size: 12, weight: .medium))
                        Text(model.screenshotFolder).font(.system(size: 11)).foregroundStyle(
                            Color.muted
                        ).lineLimit(2).textSelection(.enabled)
                    }
                    Spacer()
                    Button("Choose…") { model.chooseScreenshotFolder() }.buttonStyle(.bordered)
                }
                Label(
                    model.screenshotStatus,
                    systemImage: model.screenshotIssue == nil
                        ? "info.circle" : "exclamationmark.triangle"
                )
                .font(.system(size: 12)).foregroundStyle(
                    model.screenshotIssue == nil ? Color.muted : .orange)
                Text("Match the folder in ⇧⌘5 → Options → Save to.").font(.system(size: 12))
                    .foregroundStyle(Color.muted)
                DisclosureGroup("How collection works") {
                    Text(
                        "Only new macOS screenshot files are collected; existing files are skipped. Capture pauses with Stash. Images stay in history if you delete the originals. App exclusions apply to clipboard copies, not saved screenshots."
                    )
                    .font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(
                        horizontal: false, vertical: true
                    ).padding(.top, 8)
                }.foregroundStyle(Color.muted)

            }.id("screenshots")

        }
    }

    private var generalSettings: some View {
        Group {

            clipboardSettings

        }
    }

    private var privacySettings: some View {
        Group {

            section("Local storage") {
                Toggle(
                    "Session-only history",
                    isOn: Binding(
                        get: { model.memoryOnly },
                        set: { value in
                            if value { confirmMemory = true } else { model.memoryOnly = false }
                        })
                ).toggleStyle(.switch)
                Text(
                    model.memoryOnly
                        ? "Session only. All clips, including pins, are discarded at quit. Nothing is saved to disk."
                        : "History is stored locally. Up to 500 recent clips; pinned clips are kept. Individual copies over 20 MB are skipped."
                ).font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(
                    horizontal: false, vertical: true)
            }
            section("Excluded apps") {
                Text(
                    "Copies from these apps never enter your history. Password managers are always excluded."
                ).font(.system(size: 12)).foregroundStyle(Color.muted)
                ForEach(model.excluded, id: \.self) { id in
                    HStack {
                        Image(systemName: "app.dashed").foregroundStyle(Color.muted)

                        Text(id).font(.system(size: 11, design: .monospaced)).lineLimit(1)

                        Spacer()

                        if !StashCore.ClipboardCodec.defaultExclusions.contains(id) {
                            Button {
                                model.excluded.removeAll { $0 == id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }.buttonStyle(.plain).accessibilityLabel("Remove exclusion for \(id)")
                        }
                    }
                }
                Button("Add app…", systemImage: "plus") { model.addExcludedApp() }.buttonStyle(
                    .bordered)
            }
            section("Clear history") {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Clear unpinned history")

                        Text("Pinned clips stay right where they are.").font(.system(size: 12))
                            .foregroundStyle(Color.muted)
                    }
                    Spacer()

                    Button("Clear…", role: .destructive) { confirmClear = true }.buttonStyle(
                        .bordered)
                }
            }

        }
    }
    private var quickPasteAndEnergy: some View {
        Group {

            section("Quick Paste") {
                HStack {
                    Label(
                        trusted
                            ? "Automatic pasting is enabled"
                            : "Paste directly into your last app",
                        systemImage: trusted ? "checkmark.shield" : "keyboard")

                    Spacer()
                }
                Text(
                    "Allow Accessibility access to paste with Return. Without it, Stash copies the clip so you can paste with ⌘V."
                ).font(.system(size: 12)).foregroundStyle(Color.muted)
                if !trusted {
                    Button("Enable Quick Paste…") {
                        let key: String = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
                        let options: [String: Bool] = [key: true]
                        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

                        NSWorkspace.shared.open(
                            URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            )!)
                    }.buttonStyle(.bordered)
                }
                HStack {
                    Text("Open Stash")
                    Spacer()
                    KeyCap(text: "⌘ ⇧ V")
                }
                if let issue = model.shortcutIssue {
                    Text(issue).font(.system(size: 12)).foregroundStyle(.orange)
                }
            }
            section("Energy") {
                Label(
                    lowPower
                        ? "Low Power Mode · fewer clipboard checks" : "Adaptive energy use",
                    systemImage: "leaf")
                DisclosureGroup("How Stash saves energy") {
                    Text(
                        "Capture stops while paused, while the display sleeps, and when your session is inactive. Low Power Mode checks every 1.2 seconds; normally every 0.6 seconds. Very rapid copies between checks may be missed."
                    ).font(.system(size: 12)).foregroundStyle(Color.muted).padding(.top, 8)
                }.foregroundStyle(Color.muted)
            }

        }
    }
    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
        }
    }

    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.muted)

            VStack(alignment: .leading, spacing: 13, content: content).font(.system(size: 13)).padding(16)
                .frame(maxWidth: .infinity, alignment: .leading).background(
                    Color.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
import StashCore
