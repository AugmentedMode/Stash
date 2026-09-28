import AppKit
import StashCore

extension StashCoreTests {
    func testSavedPrompts() throws {
        let prompt = SavedPrompt(
            name: "Summarize", body: "👋 Summarize {{topic}} in a {{tone}} tone. Again: {{topic}}.")
        XCTAssertEqual(prompt.fields, ["topic", "tone"])
        XCTAssertNil(prompt.rendered(values: ["topic": "Swift"]))
        XCTAssertEqual(
            prompt.preview(values: ["topic": "Swift"]), "👋 Summarize Swift in a {{tone}} tone. Again: Swift.")
        XCTAssertEqual(prompt.preview(values: [:]), prompt.body)
        XCTAssertNil(prompt.rendered(values: ["topic": "Swift", "tone": "  "]))
        XCTAssertEqual(
            prompt.rendered(values: ["topic": "Swift", "tone": "friendly"]),
            "👋 Summarize Swift in a friendly tone. Again: Swift.")
        XCTAssertEqual(
            prompt.rendered(values: ["topic": "{{tone}}", "tone": "friendly"]),
            "👋 Summarize {{tone}} in a friendly tone. Again: {{tone}}.")
        XCTAssertEqual(SavedPrompt(name: "Plain", body: "No fields").rendered(values: [:]), "No fields")
        XCTAssertEqual(SavedPrompt(body: "{{ topic }} {{topic}} {{invalid!}}").fields, ["topic"])
        let rendered = prompt.rendered(values: ["topic": "Swift", "tone": "friendly"])!
        let destination = board()
        defer { destination.releaseGlobally() }
        let promptClip = Clip(
            sourceName: "Saved prompt", kind: .text, text: rendered,
            items: [["public.utf8-plain-text": Data(rendered.utf8)]])
        XCTAssertTrue(ClipboardCodec.restore(promptClip, to: destination, plainText: true))
        XCTAssertEqual(destination.string(forType: .string), rendered)
        XCTAssertTrue(prompt.matches("summarize tone"))
        XCTAssertTrue(!prompt.matches("unknown"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("prompts.json")
        XCTAssertEqual(try PromptDisk.load(from: url), [])
        try PromptDisk.save([prompt], to: url)
        XCTAssertEqual(try PromptDisk.load(from: url), [prompt])
        XCTAssertEqual(
            (try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)?
                .intValue, 0o600)
        try PromptDisk.save([], to: url)
        XCTAssertEqual(try PromptDisk.load(from: url), [])
        try Data("invalid".utf8).write(to: url)
        XCTAssertThrowsError(try PromptDisk.load(from: url))
    }
}
