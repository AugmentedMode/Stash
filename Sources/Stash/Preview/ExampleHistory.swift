import Foundation
import StashCore

extension AppModel {
    static func examples() -> History {
        let now = Date()
        let seeds: [(ClipKind, String, String, Bool, TimeInterval)] = [
            (
                .text,
                "Good ideas deserve a place to land.\n\nStash is a little breathing room for your clipboard. Collect what matters, keep your flow, and find it again when you need it.",
                "Notes", true, -240
            ),
            (.color, "#B7F46B", "Figma", true, -380),
            (
                .link,
                "https://app.notion.com/p/Design-system-notes-31af0a64f5cd4285ba56882b969c0b0f?source=copy_link",
                "Slack", false, -420
            ),
            (
                .text,
                "A quieter kind of productivity.\n\nLess switching. More making.\nOne small shortcut to keep everything moving.",
                "Notes", false, -900
            ),
            (.email, "hello@example.com", "Mail", false, -1500),
            (.color, "#AFA2FF", "Figma", false, -2100),
            (
                .text,
                "let ideas = clipboard.collect()\nlet next = ideas.find(\"the good one\")\nnext.paste()",
                "Xcode", false, -3500
            ),
            (.link, "https://github.com/swiftlang/swift/pull/123", "Safari", false, -90000),
            (.text, "Make room for the next good thing.", "Notes", false, -95000),
        ]
        let bundles = [
            "Notes": "com.apple.Notes", "Figma": "com.figma.Desktop", "Slack": "com.tinyspeck.slackmacgap",
            "Mail": "com.apple.mail", "Xcode": "com.apple.dt.Xcode", "Safari": "com.apple.Safari",
        ]
        let clips = seeds.map {
            Clip(
                createdAt: now.addingTimeInterval($0.4), sourceName: $0.2, sourceBundle: bundles[$0.2] ?? "",
                kind: $0.0, text: $0.1, pinned: $0.3)
        }
        return History(clips: clips + demoImages(now: now))
    }
}
