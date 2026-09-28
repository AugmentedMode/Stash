// Dependency-free test runner, usable with Command Line Tools without Xcode/XCTest.
private var failures = 0
private func fail(_ file: String, _ line: UInt) { failures += 1; print("FAIL: \(file):\(line)") }
func XCTAssertEqual<T: Equatable>(_ lhs: @autoclosure () throws -> T, _ rhs: @autoclosure () throws -> T, file: String = #fileID, line: UInt = #line) { do { if try lhs() != rhs() { fail(file, line) } } catch { fail(file, line) } }
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, file: String = #fileID, line: UInt = #line) { do { if try !value() { fail(file, line) } } catch { fail(file, line) } }
func XCTAssertNil<T>(_ value: @autoclosure () -> T?, _ message: String = "", file: String = #fileID, line: UInt = #line) { if value() != nil { fail(file, line) } }
func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, file: String = #fileID, line: UInt = #line) { if value() == nil { fail(file, line) } }
func XCTAssertGreaterThan<T: Comparable>(_ lhs: T, _ rhs: T, file: String = #fileID, line: UInt = #line) { if lhs <= rhs { fail(file, line) } }
func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, file: String = #fileID, line: UInt = #line) { do { _ = try expression(); fail(file, line) } catch {} }
import AppKit
import StashCore

final class StashCoreTests {
    func screenshotData() -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 12, pixelsHigh: 8, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 128, bitmap.bytesPerRow * bitmap.pixelsHigh)
        return bitmap.representation(using: .png, properties: [:])!
    }
    func markScreenshot(_ url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
        let result = data.withUnsafeBytes { setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, data.count, 0, 0) }
        XCTAssertEqual(result, 0)
    }
    func testScreenshotRoundTripAndDeduplication() throws {
        let data = screenshotData()
        let screenshot = ScreenshotCapture.clip(data: data)!
        XCTAssertEqual(screenshot.kind, .screenshot)
        XCTAssertNotNil(screenshot.image)
        XCTAssertTrue(screenshot.fileURLs.isEmpty)
        let destination = board(); defer { destination.releaseGlobally() }
        XCTAssertTrue(ClipboardCodec.restore(screenshot, to: destination))
        let captured = ClipboardCodec.capture(destination, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture")!
        var pinned = screenshot; pinned.pinned = true
        var history = History(clips: [pinned]); history.insert(captured)
        XCTAssertEqual(history.clips.count, 1)
        let unmarked = Clip(sourceName: "Unknown app", kind: .image, text: "Copied image", items: screenshot.items)
        history.insert(unmarked)
        XCTAssertEqual(history.clips.count, 1)
        XCTAssertEqual(history.clips.first?.kind, .screenshot)
        var unmarkedFirst = History(clips: [unmarked]); unmarkedFirst.insert(screenshot)
        XCTAssertEqual(unmarkedFirst.clips.count, 1)
        XCTAssertEqual(unmarkedFirst.clips.first?.kind, .screenshot)
        XCTAssertEqual(history.clips.first?.id, screenshot.id)
        XCTAssertEqual(history.clips.first?.pinned, true)
        XCTAssertEqual(history.filtered(query: "screenshot", kind: .screenshot).count, 1)
        XCTAssertEqual(try JSONDecoder().decode(History.self, from: JSONEncoder().encode(history)).clips, history.clips)
        destination.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        XCTAssertNil(ClipboardCodec.capture(destination, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture"))
        XCTAssertNil(ScreenshotCapture.clip(data: Data("not an image".utf8)))
        XCTAssertNil(ScreenshotCapture.clip(data: Data(count: ScreenshotCapture.maximumBytes + 1)))
    }
    func testScreenshotFileIdentityAndPersistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Renamed capture.png")
        try screenshotData().write(to: url)
        XCTAssertNil(ScreenshotCapture.load(url))
        try markScreenshot(url)
        let screenshot = ScreenshotCapture.load(url)!
        let source = board(); defer { source.releaseGlobally() }
        source.writeObjects([url as NSURL])
        XCTAssertEqual(ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "com.apple.finder")?.kind, .screenshot)
        try FileManager.default.removeItem(at: url)
        XCTAssertNotNil(screenshot.image)
        XCTAssertTrue(ClipboardCodec.restore(screenshot, to: source))
        XCTAssertNotNil(source.data(forType: .png))
    }
    func testScreenshotWatcherSkipsOldAndStops() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func write(_ name: String) throws {
            let url = directory.appendingPathComponent(name)
            try screenshotData().write(to: url); try markScreenshot(url)
        }
        try write("old.png")
        let observer = ScreenshotObserver()
        var received: [Clip] = []; var failed = false
        observer.start(folder: directory, receive: { received.append($0) }, failure: { failed = true })
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(received.isEmpty)
        try write("new.png")
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        XCTAssertTrue(!failed); XCTAssertEqual(received.count, 1)
        observer.stop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        try write("paused.png")
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        XCTAssertEqual(received.count, 1)
        observer.start(folder: directory, receive: { received.append($0) }, failure: { failed = true })
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        XCTAssertEqual(received.count, 1)
        observer.stop()
    }
    func testIdleProbeDoesNotConsumeCopy() {
        let source = board(); defer { source.releaseGlobally() }
        let observer = ClipboardObserver(board: source)
        XCTAssertTrue(!observer.hasChanges)
        source.clearContents(); source.setString("new copy", forType: .string)
        XCTAssertTrue(observer.hasChanges)
        XCTAssertTrue(observer.hasChanges)
        XCTAssertEqual(observer.read(sourceName: "Test", sourceBundle: "test")?.text, "new copy")
        XCTAssertTrue(!observer.hasChanges)
    }
    func testEnergyPolicy() {
        XCTAssertEqual(ClipboardPollingPolicy.interval(paused: false, suspended: false, lowPower: false), 0.6)
        XCTAssertEqual(ClipboardPollingPolicy.interval(paused: false, suspended: false, lowPower: true), 1.2)
        XCTAssertNil(ClipboardPollingPolicy.interval(paused: true, suspended: false, lowPower: false))
        XCTAssertNil(ClipboardPollingPolicy.interval(paused: false, suspended: true, lowPower: true))
    }
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
        let writer = HistoryWriter(delay: 0.02, write: { saved = $0; completed.signal() })
        writer.submit(History(clips: [clip("saved automatically")]))
        XCTAssertEqual(completed.wait(timeout: .now() + 2), .success)
        writer.flush()
        XCTAssertEqual(saved?.clips.first?.text, "saved automatically")
    }
    func testHistoryWriterReportsErrors() {
        struct ExpectedFailure: Error {}
        var reported = false
        let writer = HistoryWriter(delay: 60, write: { _ in throw ExpectedFailure() }, onError: { _ in reported = true })
        writer.submit(History())
        writer.flush()
        XCTAssertTrue(reported)
    }
    func testMonitorOnlyReadsNewCopies() {
        let source = board(); defer { source.releaseGlobally() }
        source.setString("before monitoring", forType: .string)
        let observer = ClipboardObserver(board: source)
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test"))
        source.clearContents(); source.setString("new copy", forType: .string)
        XCTAssertEqual(observer.read(sourceName: "Tests", sourceBundle: "test")?.text, "new copy")
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test"))
    }
    func testPausedAndExcludedCopiesDoNotReappear() {
        let source = board(); defer { source.releaseGlobally() }
        let observer = ClipboardObserver(board: source)
        source.setString("while paused", forType: .string)
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test", paused: true))
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test", paused: false))
        source.clearContents(); source.setString("private copy", forType: .string)
        XCTAssertNil(observer.read(sourceName: "Passwords", sourceBundle: "com.apple.Passwords"))
        XCTAssertNil(observer.read(sourceName: "Notes", sourceBundle: "com.apple.Notes"))
    }
    func testRestoringClipDoesNotRecaptureIt() {
        let source = board(); defer { source.releaseGlobally() }
        let observer = ClipboardObserver(board: source)
        ClipboardCodec.restore(clip("restored"), to: source)
        observer.skipCurrentChange()
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test"))
    }
    func testClassification() {
        XCTAssertEqual(ClipKind.classify("#b7f46b"), .color)
        XCTAssertEqual(ClipKind.classify("#abc"), .color)
        XCTAssertEqual(ClipKind.classify("#AABBCCDD"), .color)
        XCTAssertEqual(ClipKind.classify("hello@example.com"), .email)
        XCTAssertEqual(ClipKind.classify("https://swift.org/docs"), .link)
        XCTAssertEqual(ClipKind.classify(" https://swift.org/docs\n"), .link)
        XCTAssertEqual(ClipKind.classify("https://example.com some text"), .text)
        XCTAssertEqual(ClipKind.classify("#notacolor"), .text)
        XCTAssertEqual(ClipKind.classify("just an idea"), .text)
    }
    func board() -> NSPasteboard { NSPasteboard.withUniqueName() }
    func testRichTextRoundTrip() {
        let source = board(); let destination = board()
        defer { source.releaseGlobally(); destination.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("Hello world", forType: .string)
        item.setString("<b>Hello world</b>", forType: .html)
        source.writeObjects([item])
        let clip = ClipboardCodec.capture(source, sourceName: "Tests", sourceBundle: "test")!
        XCTAssertEqual(clip.kind, .text)
        XCTAssertTrue(ClipboardCodec.restore(clip, to: destination))
        XCTAssertEqual(destination.string(forType: .html), "<b>Hello world</b>")
        XCTAssertEqual(destination.string(forType: .string), "Hello world")
        XCTAssertTrue(ClipboardCodec.restore(clip, to: destination, plainText: true))
        XCTAssertNil(destination.string(forType: .html))
        XCTAssertEqual(destination.string(forType: .string), "Hello world")
    }
    func testSensitiveMarkersNeverCaptured() {
        for marker in ClipboardCodec.blockedTypes {
            let source = board(); defer { source.releaseGlobally() }
            source.setString("never store this", forType: .string)
            source.setData(Data(), forType: .init(marker))
            XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Tests", sourceBundle: "test"), marker)
        }
    }
    func testExcludedAppNotCaptured() {
        let source = board(); defer { source.releaseGlobally() }
        source.setString("private", forType: .string)
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Passwords", sourceBundle: "com.apple.Passwords"))
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Custom", sourceBundle: "test.custom", excluded: ["test.custom"]))
    }
    func testMultipleFilesRoundTrip() {
        let source = board(); let destination = board(); defer { source.releaseGlobally(); destination.releaseGlobally() }
        let urls = [URL(fileURLWithPath: "/tmp/stash-test-one.pdf"), URL(fileURLWithPath: "/tmp/stash-test-two.png")]
        source.writeObjects(urls as [NSURL])
        let clip = ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "com.apple.finder")!
        XCTAssertEqual(clip.kind, .file)
        XCTAssertEqual(clip.fileURLs, urls)
        ClipboardCodec.restore(clip, to: destination)
        XCTAssertEqual(destination.pasteboardItems?.count, 2)
        XCTAssertEqual(destination.pasteboardItems?.first?.string(forType: .fileURL), urls[0].absoluteString)
    }
    func testImageAndVideoTypes() {
        let source = board(); defer { source.releaseGlobally() }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        source.setData(png, forType: .png)
        let image = ClipboardCodec.capture(source, sourceName: "Preview", sourceBundle: "test")!
        XCTAssertEqual(image.kind, .image); XCTAssertNotNil(image.image)
        source.clearContents(); source.writeObjects([URL(fileURLWithPath: "/tmp/movie.mp4") as NSURL])
        XCTAssertEqual(ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "test")?.kind, .video)
    }
    func testUnsupportedAndOversizedDataSkipped() {
        let source = board(); defer { source.releaseGlobally() }
        source.setData(Data([1, 2]), forType: .init("test.unknown"))
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
        source.clearContents(); source.setData(Data(repeating: 65, count: 21 * 1024 * 1024), forType: .string)
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
    }
    func clip(_ text: String, pinned: Bool = false, date: Date = Date()) -> Clip { Clip(createdAt: date, sourceName: "Notes", kind: ClipKind.classify(text), text: text, pinned: pinned) }
    func testDeduplicationPreservesPinAndIdentity() {
        let first = clip("hello", pinned: true, date: Date(timeIntervalSince1970: 1))
        var history = History(clips: [first])
        history.insert(clip("hello"))
        XCTAssertEqual(history.clips.count, 1)
        XCTAssertEqual(history.clips[0].id, first.id)
        XCTAssertTrue(history.clips[0].pinned)
        XCTAssertGreaterThan(history.clips[0].createdAt, first.createdAt)
    }
    func testRetentionAndLimitPreservePinnedItems() {
        let old = Date().addingTimeInterval(-100 * 86400)
        var history = History(clips: [clip("keep", pinned: true, date: old), clip("expire", date: old)])
        history.expire(days: 30)
        XCTAssertEqual(history.clips.map(\.text), ["keep"])
        for index in 0..<10 { history.insert(clip("new \(index)"), limit: 3) }
        XCTAssertEqual(history.clips.count, 4)
        XCTAssertTrue(history.clips.contains { $0.text == "keep" })
    }
    func testSearchAndFilters() {
        let history = History(clips: [clip("Design systems", pinned: true), clip("https://swift.org"), clip("#ABCDEF")])
        XCTAssertEqual(history.filtered(query: "DESIGN notes").count, 1)
        XCTAssertEqual(history.filtered(query: "", kind: .link).count, 1)
        XCTAssertEqual(history.filtered(query: "", pinnedOnly: true).count, 1)
        XCTAssertEqual(history.filtered(query: "missing").count, 0)
    }
    func testLinkRecognition() {
        let notion = LinkPresentation("https://app.notion.com/p/Design-system-notes-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link")!
        XCTAssertEqual(notion.service, .notion)
        XCTAssertEqual(notion.title, "Design system notes")
        XCTAssertTrue(notion.titleFromPath)
        XCTAssertEqual(LinkPresentation("https://notion.so/31af0a64f5cd4285ba56882b969c0b0f")?.title, "Notion page")
        XCTAssertEqual(LinkPresentation("https://notion.so/Caf%C3%A9-notes-31af0a64f5cd4285ba56882b969c0b0f")?.title, "Café notes")
        XCTAssertEqual(LinkPresentation("https://github.com/swiftlang/swift/pull/123")?.title, "swiftlang/swift · PR #123")
        XCTAssertEqual(LinkPresentation("https://www.figma.com/design/opaque/Design-System?node-id=1")?.title, "Design System")
        XCTAssertEqual(LinkPresentation("https://docs.google.com/document/d/opaque/edit")?.title, "Google Docs link")
        XCTAssertEqual(LinkPresentation("https://docs.google.com/spreadsheets/d/opaque/edit")?.service, .sheets)
        XCTAssertEqual(LinkPresentation("https://docs.google.com/presentation/d/opaque/edit")?.service, .slides)
    }
    func testLinkDomainBoundaries() {
        XCTAssertEqual(LinkPresentation("https://notion.so.evil.example/Notes")?.service, .web)
        XCTAssertEqual(LinkPresentation("https://notion.so@evil.example/Notes")?.service, .web)
        XCTAssertEqual(LinkPresentation("https://notnotion.so/Notes")?.service, .web)
        XCTAssertNil(LinkPresentation("file:///tmp/example"))
        XCTAssertNil(LinkPresentation("javascript:alert(1)"))
    }
    func testLinkSearchAndOriginalPayload() {
        let original = "https://app.notion.com/p/Design-system-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link#anchor"
        let source = board(); defer { source.releaseGlobally() }
        source.setString(original, forType: .string)
        let item = ClipboardCodec.capture(source, sourceName: "Slack", sourceBundle: "com.tinyspeck.slackmacgap")!
        XCTAssertEqual(item.displayTitle, "Design system")
        XCTAssertTrue(item.matches("notion design system"))
        XCTAssertTrue(item.matches("Slack"))
        XCTAssertEqual(item.sourceName, "Slack")
        let destination = board(); defer { destination.releaseGlobally() }
        XCTAssertTrue(ClipboardCodec.restore(item, to: destination))
        XCTAssertEqual(destination.string(forType: .string), original)
        XCTAssertTrue(clip("https://docs.google.com/document/d/opaque/edit").matches("Google Docs"))
    }
    func testDiskRoundTripAndPermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.json")
        let history = History(clips: [clip("hello", pinned: true), clip("#abc")])
        try HistoryDisk.save(history, to: url)
        XCTAssertEqual(try HistoryDisk.load(from: url).clips, history.clips)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try Data("invalid".utf8).write(to: url)
        XCTAssertThrowsError(try HistoryDisk.load(from: url))
    }
    func testEmptyDiskAndEmptyClipboard() throws {
        let source = board(); defer { source.releaseGlobally() }
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertTrue(try HistoryDisk.load(from: url).clips.isEmpty)
    }
}

@main struct CoreChecks {
 static func main() {
  let suite = StashCoreTests()
  let tests: [(String, () throws -> Void)] = [
   ("ScreenshotRoundTripAndDeduplication", suite.testScreenshotRoundTripAndDeduplication),
   ("ScreenshotFileIdentityAndPersistence", suite.testScreenshotFileIdentityAndPersistence),
   ("ScreenshotWatcherSkipsOldAndStops", suite.testScreenshotWatcherSkipsOldAndStops),
   ("IdleProbeDoesNotConsumeCopy", suite.testIdleProbeDoesNotConsumeCopy),
   ("EnergyPolicy", suite.testEnergyPolicy),
   ("HistoryWritesCoalesceAndFlush", suite.testHistoryWritesCoalesceAndFlush),
   ("HistoryWritesCommitWithoutQuit", suite.testHistoryWritesCommitWithoutQuit),
   ("HistoryWriterReportsErrors", suite.testHistoryWriterReportsErrors),
   ("MonitorOnlyReadsNewCopies", suite.testMonitorOnlyReadsNewCopies),
   ("PausedAndExcludedCopiesDoNotReappear", suite.testPausedAndExcludedCopiesDoNotReappear),
   ("RestoringClipDoesNotRecaptureIt", suite.testRestoringClipDoesNotRecaptureIt),
   ("Classification", suite.testClassification),
   ("RichTextRoundTrip", suite.testRichTextRoundTrip),
   ("SensitiveMarkersNeverCaptured", suite.testSensitiveMarkersNeverCaptured),
   ("ExcludedAppNotCaptured", suite.testExcludedAppNotCaptured),
   ("MultipleFilesRoundTrip", suite.testMultipleFilesRoundTrip),
   ("ImageAndVideoTypes", suite.testImageAndVideoTypes),
   ("UnsupportedAndOversizedDataSkipped", suite.testUnsupportedAndOversizedDataSkipped),
   ("DeduplicationPreservesPinAndIdentity", suite.testDeduplicationPreservesPinAndIdentity),
   ("RetentionAndLimitPreservePinnedItems", suite.testRetentionAndLimitPreservePinnedItems),
   ("SearchAndFilters", suite.testSearchAndFilters),
   ("LinkRecognition", suite.testLinkRecognition),
   ("LinkDomainBoundaries", suite.testLinkDomainBoundaries),
   ("LinkSearchAndOriginalPayload", suite.testLinkSearchAndOriginalPayload),
   ("DiskRoundTripAndPermissions", suite.testDiskRoundTripAndPermissions),
   ("EmptyDiskAndEmptyClipboard", suite.testEmptyDiskAndEmptyClipboard)
  ]
  for (name, run) in tests { let before = failures; do { try run() } catch { failures += 1; print("FAIL: \(name) threw an error") }; if before == failures { print("PASS: \(name)") } }
  print("\(tests.count) checks, \(failures) failures")
  if failures > 0 { exit(1) }
 }
}
