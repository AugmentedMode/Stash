import AppKit
import StashCore

extension StashCoreTests {
    func testScreenshotRoundTripAndDeduplication() throws {
        let data = screenshotData()
        let screenshot = ScreenshotCapture.clip(data: data)!
        XCTAssertEqual(screenshot.kind, .screenshot)
        XCTAssertNotNil(screenshot.image)
        XCTAssertTrue(screenshot.fileURLs.isEmpty)
        let destination = board()
        defer { destination.releaseGlobally() }
        XCTAssertTrue(ClipboardCodec.restore(screenshot, to: destination))
        let captured = ClipboardCodec.capture(
            destination, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture")!
        var pinned = screenshot
        pinned.pinned = true
        var history = History(clips: [pinned])
        history.insert(captured)
        XCTAssertEqual(history.clips.count, 1)
        let unmarked = Clip(
            sourceName: "Unknown app", kind: .image, text: "Copied image", items: screenshot.items)
        history.insert(unmarked)
        XCTAssertEqual(history.clips.count, 1)
        XCTAssertEqual(history.clips.first?.kind, .screenshot)
        var unmarkedFirst = History(clips: [unmarked])
        unmarkedFirst.insert(screenshot)
        XCTAssertEqual(unmarkedFirst.clips.count, 1)
        XCTAssertEqual(unmarkedFirst.clips.first?.kind, .screenshot)
        XCTAssertEqual(history.clips.first?.id, screenshot.id)
        XCTAssertEqual(history.clips.first?.pinned, true)
        XCTAssertEqual(history.filtered(query: "screenshot", kind: .screenshot).count, 1)
        XCTAssertEqual(
            try JSONDecoder().decode(History.self, from: JSONEncoder().encode(history)).clips, history.clips)
        destination.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        XCTAssertNil(
            ClipboardCodec.capture(
                destination, sourceName: "Screenshot", sourceBundle: "com.apple.screencapture"))
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
        let source = board()
        defer { source.releaseGlobally() }
        source.writeObjects([url as NSURL])
        XCTAssertEqual(
            ClipboardCodec.capture(source, sourceName: "Finder", sourceBundle: "com.apple.finder")?.kind,
            .screenshot)
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
            try screenshotData().write(to: url)
            try markScreenshot(url)
        }
        try write("old.png")
        let observer = ScreenshotObserver()
        var received: [Clip] = []
        var failed = false
        observer.start(folder: directory, receive: { received.append($0) }, failure: { failed = true })
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        XCTAssertTrue(received.isEmpty)
        try write("new.png")
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))
        XCTAssertTrue(!failed)
        XCTAssertEqual(received.count, 1)
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
}
