import AppKit
import StashCore

extension StashCoreTests {
    func testSearchHighlightsUnicode() {
        let text = "Café CAFÉ 👩🏽‍💻 design design"
        let matches = SearchHighlight.ranges(in: text, query: "cafe design")
        XCTAssertEqual(matches.map { String(text[$0]) }, ["Café", "CAFÉ", "design", "design"])
        XCTAssertTrue(SearchHighlight.ranges(in: text, query: "   ").isEmpty)
        XCTAssertTrue(SearchHighlight.ranges(in: text, query: "missing").isEmpty)
    }
    func testRenamePreservesPayloadAndLegacyHistory() throws {
        let original = Clip(sourceName: "Notes", kind: .text, text: "Original payload")
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
        object.removeValue(forKey: "customTitle")
        let legacy = try JSONDecoder().decode(Clip.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.customTitle)
        var renamed = legacy
        renamed.customTitle = "Reusable reply"
        let decoded = try JSONDecoder().decode(Clip.self, from: JSONEncoder().encode(renamed))
        XCTAssertEqual(decoded.displayTitle, "Reusable reply")
        XCTAssertTrue(decoded.matches("reusable"))
        XCTAssertTrue(decoded.matches("original"))
        XCTAssertEqual(decoded.fingerprint, original.fingerprint)
        let pasteboard = board()
        defer { pasteboard.releaseGlobally() }
        XCTAssertTrue(ClipboardCodec.restore(decoded, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "Original payload")
        var history = History(clips: [decoded])
        history.insert(original)
        XCTAssertEqual(history.clips.count, 1)
        XCTAssertEqual(history.clips.first?.customTitle, "Reusable reply")
    }
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
        let history = History(clips: [
            clip("Design systems", pinned: true), clip("https://swift.org"), clip("#ABCDEF"),
        ])
        XCTAssertEqual(history.filtered(query: "DESIGN notes").count, 1)
        XCTAssertEqual(history.filtered(query: "", kind: .link).count, 1)
        XCTAssertEqual(history.filtered(query: "", pinnedOnly: true).count, 1)
        XCTAssertEqual(history.filtered(query: "missing").count, 0)
    }
}
