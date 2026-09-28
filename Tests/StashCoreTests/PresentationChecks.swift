import AppKit
import StashCore

extension StashCoreTests {
    func testLinkRecognition() {
        let notion = LinkPresentation(
            "https://app.notion.com/p/Design-system-notes-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link")!
        XCTAssertEqual(notion.service, .notion)
        XCTAssertEqual(notion.title, "Design system notes")
        XCTAssertTrue(notion.titleFromPath)
        XCTAssertEqual(
            LinkPresentation("https://notion.so/31af0a64f5cd4285ba56882b969c0b0f")?.title, "Notion page")
        XCTAssertEqual(
            LinkPresentation("https://notion.so/Caf%C3%A9-notes-31af0a64f5cd4285ba56882b969c0b0f")?.title,
            "Café notes")
        XCTAssertEqual(
            LinkPresentation("https://github.com/swiftlang/swift/pull/123")?.title,
            "GitHub · PR #123 · swiftlang/swift")
        XCTAssertEqual(
            LinkPresentation("https://www.figma.com/design/opaque/Design-System?node-id=1")?.title,
            "Design System")
        XCTAssertEqual(
            LinkPresentation("https://docs.google.com/document/d/opaque/edit")?.title, "Google Docs link")
        XCTAssertEqual(
            LinkPresentation("https://docs.google.com/spreadsheets/d/opaque/edit")?.service, .sheets)
        XCTAssertEqual(
            LinkPresentation("https://docs.google.com/presentation/d/opaque/edit")?.service, .slides)
    }
    func testAIRecognition() {
        let services: [(String, LinkPresentation.Service, String)] = [
            ("chatgpt.com", .chatgpt, "ChatGPT"), ("chat.openai.com", .chatgpt, "ChatGPT"),
            ("claude.ai", .claude, "Claude"), ("gemini.google.com", .gemini, "Gemini"),
            ("perplexity.ai", .perplexity, "Perplexity"),
        ]
        for (host, service, name) in services {
            let original = "https://\(host)/share/opaque?source=copy#answer"
            XCTAssertEqual(LinkPresentation(original)?.service, service)
            XCTAssertEqual(LinkPresentation(original)?.label, name)
            XCTAssertTrue(clip(original).matches(name))
            XCTAssertEqual(clip(original).text, original)
            XCTAssertEqual(LinkPresentation("https://\(host).evil.example/share")?.service, .web)
            XCTAssertEqual(LinkPresentation("https://\(host)@evil.example/share")?.service, .web)
        }
        XCTAssertEqual(LinkPresentation("https://www.perplexity.ai/search/example")?.service, .perplexity)
        XCTAssertEqual(
            Clip(
                sourceName: "Claude", sourceBundle: "com.anthropic.claudefordesktop", kind: .text,
                text: "An answer"
            ).aiSourceService, .claude)
        XCTAssertEqual(
            Clip(sourceName: "ChatGPT", sourceBundle: "com.openai.chat", kind: .text, text: "An answer")
                .aiSourceService, .chatgpt)
        XCTAssertNil(
            Clip(
                sourceName: "Chrome", sourceBundle: "com.google.Chrome", kind: .text,
                text: "ChatGPT says hello"
            ).aiSourceService)
        XCTAssertNil(
            Clip(
                sourceName: "Claude", sourceBundle: "com.anthropic.claudefordesktop", kind: .link,
                text: "https://example.com"
            ).aiSourceService)
    }
    func testExpandedServiceRecognition() {
        let cases: [(String, LinkPresentation.Service)] = [
            ("https://team.slack.com/archives/C1/p123", .slack),
            ("https://linear.app/team/issue/ABC-1", .linear),
            ("https://team.atlassian.net/browse/ABC-1", .jira),
            ("https://team.atlassian.net/jira/software/projects/ABC", .jira),
            ("https://jira.com", .jira), ("https://drive.google.com/file/d/123/view", .drive),
            ("https://www.dropbox.com/scl/fi/123/file", .dropbox),
            ("https://onedrive.live.com/?id=123", .onedrive), ("https://1drv.ms/u/s!123", .onedrive),
            ("https://youtube.com/watch?v=123", .youtube), ("https://youtu.be/123", .youtube),
            ("https://m.youtube.com/watch?v=123", .youtube), ("https://www.loom.com/share/123", .loom),
            ("https://company.zoom.us/j/123", .zoom), ("https://zoom.com/j/123", .zoom),
            ("https://meet.google.com/abc-defg-hij", .meet),
            ("https://teams.microsoft.com/l/meetup-join/123", .teams),
            ("https://teams.live.com/meet/123", .teams), ("https://teams.cloud.microsoft/meet/123", .teams),
            ("https://cursor.com/agents/123", .cursor), ("https://cursor.sh", .cursor),
            ("https://chatgpt.com/codex/tasks/123", .codex),
            ("https://copilot.microsoft.com/chats/123", .copilot),
            ("https://github.com/copilot", .copilot), ("https://copilot.github.com", .copilot),
            ("https://grok.com/share/123", .grok),
        ]
        for (original, service) in cases {
            XCTAssertEqual(LinkPresentation(original)?.service, service)
            XCTAssertTrue(clip(original).matches(service.name))
            let url = URL(string: original)!
            let host = url.host!
            XCTAssertEqual(LinkPresentation("https://\(host).evil.example\(url.path)")?.service, .web)
            XCTAssertEqual(LinkPresentation("https://\(host)@evil.example\(url.path)")?.service, .web)
        }
        XCTAssertEqual(LinkPresentation("https://team.atlassian.net/wiki/spaces/ABC")?.service, .web)
        XCTAssertEqual(LinkPresentation("https://chatgpt.com/codexish")?.service, .chatgpt)
        XCTAssertEqual(LinkPresentation("https://github.com/copilot-example/repo")?.service, .github)
        XCTAssertEqual(
            Clip(sourceName: "Codex", sourceBundle: "com.openai.codex", kind: .text, text: "hello")
                .aiSourceService, .codex)
        XCTAssertEqual(
            Clip(
                sourceName: "Cursor", sourceBundle: "com.todesktop.230313mzl4w4u92", kind: .text,
                text: "hello"
            ).aiSourceService, .cursor)
    }
    func testTextIconDetection() {
        XCTAssertEqual(TextClipStyle.detect("{\"name\": \"Stash\", \"items\": [1, 2]}"), .json)
        XCTAssertEqual(TextClipStyle.detect(" [1, true, null] "), .json)
        XCTAssertEqual(TextClipStyle.detect("```swift\nlet value = 1\n```"), .code)
        XCTAssertEqual(TextClipStyle.detect("```bash\ngit status\n```"), .command)
        XCTAssertEqual(TextClipStyle.detect("$ git status"), .command)
        XCTAssertEqual(TextClipStyle.detect("% npm install"), .command)
        XCTAssertEqual(TextClipStyle.detect("#!/bin/sh\necho hello"), .command)
        for value in [
            "hello", "{not json}", "[todo]", "42", "$ 100 due", "git is useful", "```\nA quote\n```",
            "```swift\nMissing fence", "$ git status\nSome prose",
        ] {
            XCTAssertNil(TextClipStyle.detect(value))
        }
        XCTAssertNil(TextClipStyle.detect(String(repeating: " ", count: 65_537) + "{}"))
        let original = "{\"key\": 1}"
        let item = clip(original)
        XCTAssertEqual(item.kind, .text)
        XCTAssertEqual(item.textStyle, .json)
        XCTAssertEqual(item.text, original)
        XCTAssertNil(clip("https://example.com").textStyle)
    }
    func testReadableTicketDetails() {
        XCTAssertEqual(
            LinkPresentation("https://linear.app/stash/issue/ENG-142/improve-search")?.title,
            "Linear · ENG-142")
        XCTAssertEqual(
            LinkPresentation("https://team.atlassian.net/browse/ENG-142?focusedCommentId=1")?.title,
            "Jira · ENG-142")
        XCTAssertEqual(
            LinkPresentation("https://github.com/org/repo/issues/82")?.title, "GitHub · Issue #82 · org/repo")
        XCTAssertEqual(LinkPresentation("https://linear.app/stash/issue/not-a-ticket")?.title, "Linear link")
        XCTAssertEqual(LinkPresentation("https://linear.app/stash/issue")?.title, "Linear link")
        XCTAssertEqual(LinkPresentation("https://linear.app.evil.example/stash/issue/ENG-142")?.service, .web)
        XCTAssertTrue(clip("https://linear.app/stash/issue/ENG-142/title").matches("linear eng-142"))
    }
    func testLinkDomainBoundaries() {
        XCTAssertEqual(LinkPresentation("https://notion.so.evil.example/Notes")?.service, .web)
        XCTAssertEqual(LinkPresentation("https://notion.so@evil.example/Notes")?.service, .web)
        XCTAssertEqual(LinkPresentation("https://notnotion.so/Notes")?.service, .web)
        XCTAssertNil(LinkPresentation("file:///tmp/example"))
        XCTAssertNil(LinkPresentation("javascript:alert(1)"))
    }
    func testLinkSearchAndOriginalPayload() {
        let original =
            "https://app.notion.com/p/Design-system-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link#anchor"
        let source = board()
        defer { source.releaseGlobally() }
        source.setString(original, forType: .string)
        let item = ClipboardCodec.capture(
            source, sourceName: "Slack", sourceBundle: "com.tinyspeck.slackmacgap")!
        XCTAssertEqual(item.displayTitle, "Design system")
        XCTAssertTrue(item.matches("notion design system"))
        XCTAssertTrue(item.matches("Slack"))
        XCTAssertEqual(item.sourceName, "Slack")
        let destination = board()
        defer { destination.releaseGlobally() }
        XCTAssertTrue(ClipboardCodec.restore(item, to: destination))
        XCTAssertEqual(destination.string(forType: .string), original)
        XCTAssertTrue(clip("https://docs.google.com/document/d/opaque/edit").matches("Google Docs"))
    }
}
