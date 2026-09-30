import AppKit
import StashCore

extension StashCoreTests {
    private func imageClip(_ name: String) -> Clip {
        Clip(
            sourceName: "Preview", kind: .image, text: name,
            items: [[NSPasteboard.PasteboardType.png.rawValue: screenshotData() + Data(name.utf8)]])
    }
    private func payloadFiles(_ directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("payloads"),
            includingPropertiesForKeys: [.contentModificationDateKey]))
            ?? []
    }
    func testStoreRoundTripKeepsPayloadsOutOfIndex() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rich = Clip(
            sourceName: "Notes", kind: .text, text: "Hello",
            items: [
                ["public.utf8-plain-text": Data("Hello".utf8), "public.html": Data("<b>Hello</b>".utf8)]
            ],
            sourceTitle: "Draft")
        let history = History(clips: [imageClip("one"), rich, clip("plain", pinned: true)])
        try HistoryStore(directory: directory).save(history)
        let loaded = try HistoryStore(directory: directory).load()
        XCTAssertEqual(loaded.clips, history.clips)
        XCTAssertEqual(loaded.clips.map(\.fingerprint), history.clips.map(\.fingerprint))
        // Two clips carry pasteboard data; the plain one lives only in the index.
        XCTAssertEqual(payloadFiles(directory).count, 2)
        let index = try String(contentsOf: directory.appendingPathComponent("index.json"), encoding: .utf8)
        XCTAssertTrue(!index.contains("<b>Hello</b>") && !index.contains("PNG"))
        for url in [directory, directory.appendingPathComponent("index.json")] + payloadFiles(directory) {
            let mode =
                try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
            XCTAssertEqual(mode?.intValue, url == directory ? 0o700 : 0o600)
        }
    }
    func testStoreWritesOnlyNewPayloadsAndRemovesOldOnes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        var history = History(clips: [imageClip("first"), imageClip("second")])
        try store.save(history)
        let firstFile = payloadFiles(directory).first {
            $0.lastPathComponent.hasPrefix(history.clips[0].id.uuidString)
        }!
        let firstInode =
            try FileManager.default.attributesOfItem(atPath: firstFile.path)[.systemFileNumber] as? NSNumber
        history.insert(imageClip("third"))
        history.clips[1].pinned = true
        try store.save(history)
        // Existing payloads are not rewritten; an atomic rewrite would replace the file.
        XCTAssertEqual(
            try FileManager.default.attributesOfItem(atPath: firstFile.path)[.systemFileNumber] as? NSNumber,
            firstInode)
        XCTAssertEqual(payloadFiles(directory).count, 3)
        history.clips.removeAll { $0.text == "second" }
        try store.save(history)
        XCTAssertEqual(payloadFiles(directory).count, 2)
        XCTAssertEqual(try HistoryStore(directory: directory).load().clips, history.clips)
        XCTAssertGreaterThan(store.bytesOnDisk, 0)
        // Session-only mode saves an empty history, which must erase every payload.
        try store.save(History())
        XCTAssertEqual(payloadFiles(directory).count, 0)
        XCTAssertTrue(try HistoryStore(directory: directory).load().clips.isEmpty)
    }
    func testStoreMigratesLegacyHistoryOnce() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("history.json")
        let history = History(clips: [imageClip("old image"), clip("old text", pinned: true)])
        try HistoryDisk.save(history, to: legacy)
        let directory = root.appendingPathComponent("History")
        XCTAssertEqual(try HistoryStore(directory: directory, legacyURL: legacy).load().clips, history.clips)
        XCTAssertTrue(!FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try HistoryStore(directory: directory, legacyURL: legacy).load().clips, history.clips)
    }
    func testStoreLeavesUnreadableDataUntouched() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        // A corrupt legacy file fails to load and is not deleted.
        let legacy = root.appendingPathComponent("history.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("invalid".utf8).write(to: legacy)
        let directory = root.appendingPathComponent("History")
        XCTAssertThrowsError(try HistoryStore(directory: directory, legacyURL: legacy).load())
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        // A corrupt index fails to load.
        try HistoryStore(directory: directory).save(History(clips: [clip("kept")]))
        try Data("invalid".utf8).write(to: directory.appendingPathComponent("index.json"))
        XCTAssertThrowsError(try HistoryStore(directory: directory).load())
    }
    func testStoreDropsImagesWhosePayloadIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rich = Clip(
            sourceName: "Notes", kind: .text, text: "still here",
            items: [["public.html": Data("<i>still here</i>".utf8)]])
        try HistoryStore(directory: directory).save(History(clips: [imageClip("lost"), rich]))
        for file in payloadFiles(directory) { try FileManager.default.removeItem(at: file) }
        let loaded = try HistoryStore(directory: directory).load()
        XCTAssertEqual(loaded.clips.map(\.text), ["still here"])
    }
}
