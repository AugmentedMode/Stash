import Foundation
import StashCore

extension StashCoreTests {
    func testSharePromptWaitsForRealUse() {
        var prompt = SharePrompt()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 24 * 60 * 60
        // Pasting the newest clip is what ⌘V does anyway, so it never counts.
        for _ in 0..<20 { prompt.recordRecall(position: 0, at: start) }
        XCTAssertEqual(prompt.recalls, 0)
        // Plenty of recalls on one day is not enough.
        for _ in 0..<12 { prompt.recordRecall(position: 3, at: start) }
        XCTAssertFalse(prompt.shouldShow(at: start))
        prompt.recordRecall(position: 1, at: start + day)
        XCTAssertFalse(prompt.shouldShow(at: start + day))
        prompt.recordRecall(position: 1, at: start + 2 * day)
        XCTAssertTrue(prompt.shouldShow(at: start + 2 * day))
    }
    func testSharePromptAsksAtMostTwice() {
        var prompt = SharePrompt()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let day: TimeInterval = 24 * 60 * 60
        for n in 0..<12 { prompt.recordRecall(position: 2, at: start + Double(n % 3) * day) }
        let asked = start + 3 * day
        XCTAssertTrue(prompt.shouldShow(at: asked))
        prompt.later(at: asked)
        XCTAssertFalse(prompt.shouldShow(at: asked + 20 * day))
        XCTAssertTrue(prompt.shouldShow(at: asked + 21 * day))
        prompt.later(at: asked + 21 * day)
        XCTAssertFalse(prompt.shouldShow(at: asked + 400 * day))
    }
    func testSharePromptStopsAfterShareAndSurvivesRelaunch() throws {
        var prompt = SharePrompt()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for n in 0..<12 { prompt.recordRecall(position: 1, at: start + Double(n) * 24 * 60 * 60) }
        let restored = try JSONDecoder().decode(SharePrompt.self, from: JSONEncoder().encode(prompt))
        XCTAssertEqual(restored, prompt)
        prompt.done()
        XCTAssertFalse(prompt.shouldShow(at: start + 1000 * 24 * 60 * 60))
        prompt.recordRecall(position: 5, at: start)
        XCTAssertEqual(prompt.recalls, 12)
    }
}
