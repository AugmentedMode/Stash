import SwiftUI
import AppKit
import ApplicationServices

struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ClipStackIllustration().frame(height: 112)
            Text("A little space for\neverything you copy.").font(.system(size: 31, weight: .medium)).tracking(-1.4).multilineTextAlignment(.center)
            Text("Copy freely. Find it instantly. Keep your flow.").font(.system(size: 16)).foregroundStyle(Color.muted)
            HStack(spacing: 27) { Label("Local history", systemImage: "lock.shield"); Label("No account", systemImage: "person.crop.circle.badge.checkmark"); Label("No tracking", systemImage: "eye.slash") }.font(.system(size: 12)).foregroundStyle(Color.muted).padding(.top, 4)
            VStack(spacing: 12) {
                Button { model.start() } label: { HStack(spacing: 34) { Text("Start collecting"); Image(systemName: "arrow.right") }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.canvas).padding(.horizontal, 23).padding(.vertical, 14).background(Color.accent, in: RoundedRectangle(cornerRadius: 12)) }.buttonStyle(.plain)
                Text("Saves new copies on this Mac for 30 days.\nPassword-manager marked secrets are skipped.").font(.system(size: 12)).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(4)
            }.padding(.top, 12)
            Spacer()
            HStack(spacing: 7) { Text("Always one shortcut away").foregroundStyle(Color.muted); KeyCap(text: "⌘"); KeyCap(text: "⇧"); KeyCap(text: "V") }.font(.system(size: 12)).padding(.bottom, 24)
        }.frame(maxWidth: .infinity).padding(.top, 22)
    }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var confirmClear = false
    @State private var confirmMemory = false
    @State private var trusted = AXIsProcessTrusted()
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text("Settings").font(.system(size: 23, weight: .medium)).tracking(-0.5); Text("Clipboard, privacy, and pasting.").font(.system(size: 13)).foregroundStyle(Color.muted) }; Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 21)).foregroundStyle(Color.muted) }.buttonStyle(.plain).accessibilityLabel("Close settings") }.padding(26)
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("CAPTURE & HISTORY") {
                        Toggle("Pause all capture", isOn: $model.paused).toggleStyle(.switch)
                        Divider().overlay(Color.line)
                        HStack { Text("Keep unpinned clips for"); Spacer(); Picker("History retention", selection: $model.retention) { Text("1 day").tag(1); Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90); Text("Forever").tag(0) }.labelsHidden().frame(width: 115) }
                        Divider().overlay(Color.line)
                        Toggle("Clear history when Stash quits", isOn: Binding(get: { model.memoryOnly }, set: { value in if value { confirmMemory = true } else { model.memoryOnly = false } })).toggleStyle(.switch)
                        Text(model.memoryOnly ? "Session only. All clips, including pins, are discarded at quit. Nothing is saved to disk." : "History is stored locally. Up to 500 recent clips; pinned clips are kept. Individual copies over 20 MB are skipped.").font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    section("SCREENSHOTS") {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "camera.viewfinder").font(.system(size: 26)).foregroundStyle(Color.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Screenshot. Paste. Done.").font(.system(size: 16, weight: .semibold))
                                Text("New screenshots, together in one place. Ready for your next message.").font(.system(size: 12)).foregroundStyle(Color.muted)
                            }
                        }
                        Toggle("Collect saved screenshots", isOn: $model.screenshotsEnabled).toggleStyle(.switch)
                        if model.screenshotsEnabled {
                            Toggle("Copy new screenshots to clipboard", isOn: $model.screenshotAutoCopy).toggleStyle(.switch)
                            Text(model.screenshotAutoCopy ? "Take a screenshot, then press ⌘V after it saves. A newer clipboard copy takes priority." : "Screenshots go into history. Your clipboard stays as it is.")
                                .font(.system(size: 12)).foregroundStyle(Color.muted)
                        }
                        Divider().overlay(Color.line)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Screenshot save folder").font(.system(size: 12, weight: .medium))
                                Text(model.screenshotFolder).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(2).textSelection(.enabled)
                            }
                            Spacer()
                            Button("Choose…") { model.chooseScreenshotFolder() }.buttonStyle(.bordered)
                        }
                        Label(model.screenshotStatus, systemImage: model.screenshotIssue == nil ? "info.circle" : "exclamationmark.triangle")
                            .font(.system(size: 12)).foregroundStyle(model.screenshotIssue == nil ? Color.muted : .orange)
                        Text("Match the folder in ⇧⌘5 → Options → Save to. Only new macOS screenshot files are collected; existing files are skipped. Capture pauses with Stash. Images stay in history if you delete the originals. App exclusions apply to clipboard copies, not saved screenshots.")
                            .font(.system(size: 12)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                    }.id("screenshots")
                    section("ENERGY") {
                        Label(model.lowPower ? "Low Power Mode · fewer clipboard checks" : "Adaptive energy use", systemImage: "leaf")
                        Text("Capture stops while paused, while the display sleeps, and when your session is inactive. Low Power Mode checks every 1.2 seconds; normally every 0.6 seconds. Very rapid copies between checks may be missed.").font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                    section("QUICK PASTE") {
                        HStack { Label(trusted ? "Automatic pasting is enabled" : "Paste directly into your last app", systemImage: trusted ? "checkmark.shield" : "keyboard"); Spacer() }
                        Text("Allow Accessibility access to paste with Return. Without it, Stash copies the clip so you can paste with ⌘V.").font(.system(size: 12)).foregroundStyle(Color.muted)
                        if !trusted { Button("Enable Quick Paste…") { let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options); NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }.buttonStyle(.bordered) }
                        HStack { Text("Open Stash"); Spacer(); KeyCap(text: "⌘ ⇧ V") }
                        if let issue = model.shortcutIssue { Text(issue).font(.system(size: 12)).foregroundStyle(.orange) }
                    }
                    section("EXCLUDED APPS") {
                        Text("Copies from these apps never enter your history. Password managers are always excluded.").font(.system(size: 12)).foregroundStyle(Color.muted)
                        ForEach(model.excluded, id: \.self) { id in HStack { Image(systemName: "app.dashed").foregroundStyle(Color.muted); Text(id).font(.system(size: 11, design: .monospaced)).lineLimit(1); Spacer(); if !StashCore.ClipboardCodec.defaultExclusions.contains(id) { Button { model.excluded.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove exclusion for \(id)") } } }
                        Button("Add app…", systemImage: "plus") { model.addExcludedApp() }.buttonStyle(.bordered)
                    }
                    section("A CLEAN SLATE") {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text("Clear unpinned history"); Text("Pinned clips stay right where they are.").font(.system(size: 12)).foregroundStyle(Color.muted) }; Spacer(); Button("Clear…", role: .destructive) { confirmClear = true }.buttonStyle(.bordered) }
                    }
                    HStack { Text("Stash 1.0 · Made for your flow"); Spacer(); Button("Quit Stash") { NSApp.terminate(nil) }.buttonStyle(.plain) }.font(.system(size: 11)).foregroundStyle(Color.muted)
                }.padding(.horizontal, 26).padding(.bottom, 26)
            }
            .onAppear {
                if model.screenshotSettingsRequested {
                    DispatchQueue.main.async { proxy.scrollTo("screenshots", anchor: .top) }
                }
            }
            .onDisappear { model.screenshotSettingsRequested = false }
            }
        }.frame(width: 540, height: 510).background(Color.canvas).preferredColorScheme(.dark).tint(.accent)
        .onReceive(refresh) { _ in trusted = AXIsProcessTrusted() }
        .alert("Clear unpinned history?", isPresented: $confirmClear) { Button("Cancel", role: .cancel) {}; Button("Clear history", role: .destructive) { model.clearHistory() } } message: { Text("This removes unpinned clips from Stash. Your pinned clips and current clipboard are kept.") }
        .alert("Use session-only history?", isPresented: $confirmMemory) { Button("Cancel", role: .cancel) {}; Button("Use session only", role: .destructive) { model.memoryOnly = true } } message: { Text("The saved history on disk will be cleared. Current clips stay available until Stash quits, including pinned clips.") }
    }
    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Color.muted); VStack(alignment: .leading, spacing: 13, content: content).font(.system(size: 13)).padding(16).background(Color.surface, in: RoundedRectangle(cornerRadius: 12)) }
    }
}
import StashCore
