import AppKit
import StashCore

extension StashCoreTests {
    func testHistoryWritesCoalesceAndFlush() {
        var writes: [History] = []
        let writer = HistoryWriter(delay: 60, write: { writes.append($0) })
        for n in 0..<100 { writer.submit(History(clips: [clip("copy \(n)")])) }
        writer.flush()
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.last?.clips.first?.text, "copy 99")
        writer.flush()
        XCTAssertEqual(writes.count, 1)
        writer.submit(History(clips: [clip("pending before session-only")]))
        writer.submit(History(), immediately: true)
        writer.flush()
        XCTAssertEqual(writes.count, 2)
        XCTAssertTrue(writes.last!.clips.isEmpty)
    }
    func testHistoryWritesCommitWithoutQuit() {
        let completed = DispatchSemaphore(value: 0)
        var saved: History?
        let writer = HistoryWriter(
            delay: 0.02,
            write: {
                saved = $0
                completed.signal()
            })
        writer.submit(History(clips: [clip("saved automatically")]))
        XCTAssertEqual(completed.wait(timeout: .now() + 2), .success)
        writer.flush()
        XCTAssertEqual(saved?.clips.first?.text, "saved automatically")
    }
    func testHistoryWriterReportsErrors() {
        struct ExpectedFailure: Error {}
        var reported = false
        let writer = HistoryWriter(
            delay: 60, write: { _ in throw ExpectedFailure() }, onError: { _ in reported = true })
        writer.submit(History())
        writer.flush()
        XCTAssertTrue(reported)
    }
    func testDiskRoundTripAndPermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json")
        let history = History(clips: [clip("hello", pinned: true), clip("#abc")])
        try HistoryDisk.save(history, to: url)
        XCTAssertEqual(try HistoryDisk.load(from: url).clips, history.clips)
        XCTAssertEqual(
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?
                .intValue, 0o600)
        try Data("invalid".utf8).write(to: url)
        XCTAssertThrowsError(try HistoryDisk.load(from: url))
    }
    func testEmptyDiskAndEmptyClipboard() throws {
        let source = board()
        defer { source.releaseGlobally() }
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertTrue(try HistoryDisk.load(from: url).clips.isEmpty)
    }
}
