import AppKit
import StashCore

extension StashCoreTests {
    func testIdleProbeDoesNotConsumeCopy() {
        let source = board()
        defer { source.releaseGlobally() }
        let observer = ClipboardObserver(board: source)
        XCTAssertTrue(!observer.hasChanges)
        source.clearContents()
        source.setString("new copy", forType: .string)
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
    func testMonitorOnlyReadsNewCopies() {
        let source = board()
        defer { source.releaseGlobally() }
        source.setString("before monitoring", forType: .string)
        let observer = ClipboardObserver(board: source)
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test"))
        source.clearContents()
        source.setString("new copy", forType: .string)
        XCTAssertEqual(observer.read(sourceName: "Tests", sourceBundle: "test")?.text, "new copy")
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test"))
    }
    func testPausedAndExcludedCopiesDoNotReappear() {
        let source = board()
        defer { source.releaseGlobally() }
        let observer = ClipboardObserver(board: source)
        source.setString("while paused", forType: .string)
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test", paused: true))
        XCTAssertNil(observer.read(sourceName: "Tests", sourceBundle: "test", paused: false))
        source.clearContents()
        source.setString("private copy", forType: .string)
        XCTAssertNil(observer.read(sourceName: "Passwords", sourceBundle: "com.apple.Passwords"))
        XCTAssertNil(observer.read(sourceName: "Notes", sourceBundle: "com.apple.Notes"))
    }
    func testRestoringClipDoesNotRecaptureIt() {
        let source = board()
        defer { source.releaseGlobally() }
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
    func testRichTextRoundTrip() {
        let source = board()
        let destination = board()
        defer {
            source.releaseGlobally()
            destination.releaseGlobally()
        }
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
            let source = board()
            defer { source.releaseGlobally() }
            source.setString("never store this", forType: .string)
            source.setData(Data(), forType: .init(marker))
            XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Tests", sourceBundle: "test"), marker)
        }
    }
    func testExcludedAppNotCaptured() {
        let source = board()
        defer { source.releaseGlobally() }
        source.setString("private", forType: .string)
        XCTAssertNil(
            ClipboardCodec.capture(source, sourceName: "Passwords", sourceBundle: "com.apple.Passwords"))
        XCTAssertNil(
            ClipboardCodec.capture(
                source, sourceName: "Custom", sourceBundle: "test.custom", excluded: ["test.custom"]))
    }
    func testMultipleFilesRoundTrip() {
        let source = board()
        let destination = board()

        defer {
            source.releaseGlobally()
            destination.releaseGlobally()
        }
        let urls = [
            URL(fileURLWithPath: "/tmp/stash-test-one.pdf"), URL(fileURLWithPath: "/tmp/stash-test-two.png"),
        ]
        source.writeObjects(urls as [NSURL])
        let clip = ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "com.apple.finder")!
        XCTAssertEqual(clip.kind, .file)
        XCTAssertEqual(clip.fileURLs, urls)
        ClipboardCodec.restore(clip, to: destination)
        XCTAssertEqual(destination.pasteboardItems?.count, 2)
        XCTAssertEqual(destination.pasteboardItems?.first?.string(forType: .fileURL), urls[0].absoluteString)
    }
    func testImageAndVideoTypes() {
        let source = board()
        defer { source.releaseGlobally() }
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = bitmap.representation(using: .png, properties: [:])!
        source.setData(png, forType: .png)
        let image = ClipboardCodec.capture(source, sourceName: "Preview", sourceBundle: "test")!
        XCTAssertEqual(image.kind, .image)
        XCTAssertNotNil(image.image)
        source.clearContents()
        source.writeObjects([URL(fileURLWithPath: "/tmp/movie.mp4") as NSURL])
        XCTAssertEqual(
            ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "test")?.kind, .video)
    }
    func testUnsupportedAndOversizedDataSkipped() {
        let source = board()
        defer { source.releaseGlobally() }
        source.setData(Data([1, 2]), forType: .init("test.unknown"))
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
        source.clearContents()
        source.setData(Data(repeating: 65, count: 21 * 1024 * 1024), forType: .string)
        XCTAssertNil(ClipboardCodec.capture(source, sourceName: "Test", sourceBundle: "test"))
    }
}
extension StashCoreTests {
    func testCaptureKeepsWhereTheCopyCameFrom() {
        let source = board()
        let destination = board()
        defer {
            source.releaseGlobally()
            destination.releaseGlobally()
        }
        let item = NSPasteboardItem()
        item.setString("alias claude-sec", forType: .string)
        item.setString(
            "https://www.example.com/docs?q=1", forType: .init(ClipboardCodec.chromiumSourceURLType))
        source.writeObjects([item])
        let clip = ClipboardCodec.capture(
            source, sourceName: "Arc", sourceBundle: "company.thebrowser.Browser",
            sourceTitle: "  Setup guide  ")!
        XCTAssertEqual(clip.sourceTitle, "Setup guide")
        XCTAssertEqual(clip.sourceURL, "https://www.example.com/docs?q=1")
        XCTAssertEqual(clip.sourceHost, "example.com")
        XCTAssertEqual(clip.sourceContext, "Setup guide")
        XCTAssertTrue(clip.matches("setup guide"))
        XCTAssertTrue(clip.matches("example.com"))
        // Provenance is metadata only: it is not pasted back out.
        ClipboardCodec.restore(clip, to: destination)
        XCTAssertNil(destination.string(forType: .init(ClipboardCodec.chromiumSourceURLType)))
    }
    func testCaptureIgnoresUnsafeOrRedundantSources() {
        let source = board()
        defer { source.releaseGlobally() }
        let item = NSPasteboardItem()
        item.setString("hello", forType: .string)
        item.setString("javascript:alert(1)", forType: .init(ClipboardCodec.chromiumSourceURLType))
        source.writeObjects([item])
        let clip = ClipboardCodec.capture(
            source, sourceName: "Slack", sourceBundle: "test", sourceTitle: "Slack")!
        XCTAssertNil(clip.sourceURL)
        XCTAssertNil(clip.sourceTitle)
        XCTAssertNil(clip.sourceContext)
    }
    func testRecopyUpdatesSourceAndOldHistoryDecodes() throws {
        var history = History()
        history.insert(Clip(sourceName: "Arc", kind: .text, text: "same", sourceTitle: "Old page"))
        history.insert(Clip(sourceName: "Slack", kind: .text, text: "same", sourceTitle: "#general"))
        XCTAssertEqual(history.clips.count, 1)
        XCTAssertEqual(history.clips[0].sourceTitle, "#general")
        let legacy = """
            {"id":"\(UUID().uuidString)","createdAt":0,"sourceName":"Notes","sourceBundle":"","kind":"text",
            "text":"old","pinned":false,"items":[],"fingerprint":"x"}
            """
        let clip = try JSONDecoder().decode(Clip.self, from: Data(legacy.utf8))
        XCTAssertNil(clip.sourceTitle)
        XCTAssertNil(clip.sourceURL)
    }
}
