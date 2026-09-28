import AppKit
import StashCore

extension StashCoreTests {
    func testPinnedPayloadDoesNotConsumeHistoryBudget() {
        let pin = Clip(
            sourceName: "Test", kind: .text, text: "pinned", pinned: true,
            items: [["public.utf8-plain-text": Data(count: 100)]])
        let recent = Clip(
            sourceName: "Test", kind: .text, text: "recent",
            items: [["public.utf8-plain-text": Data(count: 4)]])
        let old = Clip(
            sourceName: "Test", kind: .text, text: "old",
            items: [["public.utf8-plain-text": Data(count: 4)]])
        var history = History(clips: [pin, old])
        history.insert(recent, limit: 2, maximumBytes: 8)
        XCTAssertEqual(history.clips.map(\.id), [recent.id, pin.id, old.id])
        history.enforceLimits(count: 1, bytes: 4)
        XCTAssertEqual(history.clips.map(\.id), [recent.id, pin.id])
        history.enforceLimits(count: -1, bytes: -1)
        XCTAssertEqual(history.clips.map(\.id), [pin.id])
    }

    func testHistoryBudgetKeepsNewestPrefix() {
        let clips = [2, 8, 1].map { size in
            Clip(
                sourceName: "Test", kind: .text, text: String(size),
                items: [["public.utf8-plain-text": Data(count: size)]])
        }
        var history = History(clips: clips)
        history.enforceLimits(bytes: 5)
        XCTAssertEqual(history.clips.map(\.id), [clips[0].id])
    }

    func testCompiledSearchPreservesMatching() {
        let search = SearchQuery("  CAFÉ\n design  ")
        let item = clip("Cafe design notes")
        XCTAssertTrue(item.matches(search))
        XCTAssertTrue(SavedPrompt(name: "Café", body: "Design review").matches(search))
        XCTAssertTrue(!item.matches(SearchQuery("cafe missing")))
        XCTAssertTrue(clip("").matches(SearchQuery("  \n")))
    }

    func testPromptValidationUsesUTF8Budget() {
        XCTAssertTrue(!SavedPrompt(name: "   ", body: "value").isValid)
        XCTAssertTrue(!SavedPrompt(name: "Name", body: " \n").isValid)
        XCTAssertTrue(SavedPrompt(name: String(repeating: "a", count: 100), body: "ok").isValid)
        XCTAssertTrue(!SavedPrompt(name: String(repeating: "a", count: 101), body: "ok").isValid)
        XCTAssertTrue(SavedPrompt(name: "Name", body: String(repeating: "a", count: 65_536)).isValid)
        XCTAssertTrue(!SavedPrompt(name: "Name", body: String(repeating: "👩", count: 20_000)).isValid)
    }

    func testPrivateStoreRepairsPermissionsAndReplacesData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
        let url = directory.appendingPathComponent("prompts.json")
        try PromptDisk.save([SavedPrompt(name: "First", body: "one")], to: url)
        try PromptDisk.save([SavedPrompt(name: "Second", body: "two")], to: url)
        XCTAssertEqual(try PromptDisk.load(from: url).map(\.name), ["Second"])
        XCTAssertEqual(
            (try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?
                .intValue, 0o700)
        XCTAssertEqual(
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?
                .intValue, 0o600)
        let invalid = Data("invalid JSON".utf8)
        try invalid.write(to: url)
        XCTAssertThrowsError(try PromptDisk.load(from: url))
        XCTAssertEqual(try Data(contentsOf: url), invalid)
    }

    func testScreenshotStopCancelsQueuedFailure() {
        let observer = ScreenshotObserver()
        var failures = 0
        observer.start(
            folder: URL(fileURLWithPath: "/nonexistent-stash-\(UUID())"), receive: { _ in },
            failure: { failures += 1 })
        observer.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(failures, 0)
    }

    func testScreenshotObserverReleasesWhileWatching() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var observer: ScreenshotObserver? = ScreenshotObserver()
        final class WeakObserver { weak var value: ScreenshotObserver? }
        let reference = WeakObserver()
        reference.value = observer
        observer?.start(folder: folder, receive: { _ in }, failure: {})
        observer = nil
        let deadline = Date().addingTimeInterval(2)
        while reference.value != nil, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertNil(reference.value)
    }
}
