import Foundation

/// Offline display metadata only. Never substitutes for the original URL payload.
public struct LinkPresentation: Equatable {
    public enum Service: String, CaseIterable {
        case notion, github, figma, docs, sheets, slides, chatgpt, claude, gemini, perplexity
        case slack, linear, jira, drive, dropbox, onedrive, youtube, loom, zoom, meet, teams
        case cursor, codex, copilot, grok, web

        public var name: String {
            switch self {
            case .notion: return "Notion"
            case .github: return "GitHub"
            case .figma: return "Figma"
            case .docs: return "Google Docs"
            case .sheets: return "Google Sheets"
            case .slides: return "Google Slides"
            case .chatgpt: return "ChatGPT"
            case .claude: return "Claude"
            case .gemini: return "Gemini"
            case .perplexity: return "Perplexity"
            case .slack: return "Slack"
            case .linear: return "Linear"
            case .jira: return "Jira"
            case .drive: return "Google Drive"
            case .dropbox: return "Dropbox"
            case .onedrive: return "OneDrive"
            case .youtube: return "YouTube"
            case .loom: return "Loom"
            case .zoom: return "Zoom"
            case .meet: return "Google Meet"
            case .teams: return "Microsoft Teams"
            case .cursor: return "Cursor"
            case .codex: return "Codex"
            case .copilot: return "Copilot"
            case .grok: return "Grok"
            case .web: return "Web"
            }
        }
    }

    private static let exactServices: [String: Service] = [
        "chatgpt.com": .chatgpt, "chat.openai.com": .chatgpt, "claude.ai": .claude,
        "gemini.google.com": .gemini, "perplexity.ai": .perplexity,
        "linear.app": .linear, "jira.com": .jira, "drive.google.com": .drive,
        "onedrive.live.com": .onedrive, "1drv.ms": .onedrive,
        "youtube.com": .youtube, "m.youtube.com": .youtube, "youtu.be": .youtube,
        "meet.google.com": .meet, "teams.microsoft.com": .teams, "teams.live.com": .teams,
        "teams.cloud.microsoft": .teams, "cursor.com": .cursor, "cursor.sh": .cursor,
        "copilot.microsoft.com": .copilot, "copilot.github.com": .copilot, "grok.com": .grok
    ]

    private static let workspaceServices: [(String, Service)] = [
        ("slack.com", .slack), ("dropbox.com", .dropbox), ("loom.com", .loom),
        ("zoom.us", .zoom), ("zoom.com", .zoom)
    ]
    public let service: Service
    public let title: String
    public let host: String
    public let label: String
    public let titleFromPath: Bool

    public init?(_ original: String) {
        guard let url = URL(string: original.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let rawHost = url.host?.lowercased() else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        self.host = host
        let parts = url.path.split(separator: "/").map(String.init)
        func belongs(to domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        func readable(_ value: String) -> String {
            value.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
                .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        }
        // Path-scoped products take precedence over their parent site's logo.
        let recognized: Service?
        if host == "chatgpt.com", parts.first == "codex" { recognized = .codex }
        else if host == "github.com", parts.first == "copilot" { recognized = .copilot }
        else if belongs(to: "atlassian.net"), let first = parts.first, ["browse", "jira"].contains(first) { recognized = .jira }
        else {
            recognized = Self.exactServices[host]
                ?? Self.workspaceServices.first(where: { belongs(to: $0.0) })?.1
        }
        if let recognized {
            service = recognized; label = recognized.name
            title = recognized.name + " link"; titleFromPath = false
            return
        }
        if belongs(to: "notion.so") || belongs(to: "notion.site") || belongs(to: "notion.com") {
            service = .notion; label = "Notion page"
            let slug = (parts.last ?? "").replacingOccurrences(of: "(?:-)?[0-9a-fA-F]{32}$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "(?:-)?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", with: "", options: .regularExpression)
            let name = readable(slug)
            let useful = !name.isEmpty && !["p", "login", "signup"].contains(name.lowercased())
            title = useful ? name : "Notion page"; titleFromPath = useful
        } else if host == "github.com" {
            service = .github; label = "GitHub"
            if parts.count >= 4, ["pull", "issues"].contains(parts[2]), Int(parts[3]) != nil {
                title = "\(parts[0])/\(parts[1]) · \(parts[2] == "pull" ? "PR" : "Issue") #\(parts[3])"
            } else if parts.count >= 2 { title = "\(parts[0])/\(parts[1])" }
            else { title = parts.first ?? "GitHub" }
            titleFromPath = !parts.isEmpty
        } else if belongs(to: "figma.com") {
            service = .figma; label = "Figma"
            let useful = parts.count >= 3 && ["design", "file", "proto", "board", "slides"].contains(parts[0])
            title = useful ? readable(parts[2]) : "Figma link"; titleFromPath = useful
        } else if host == "docs.google.com", let type = parts.first, ["document", "spreadsheets", "presentation"].contains(type) {
            service = type == "document" ? .docs : type == "spreadsheets" ? .sheets : .slides
            label = type == "document" ? "Google Docs" : type == "spreadsheets" ? "Google Sheets" : "Google Slides"
            title = label + " link"; titleFromPath = false
        } else {
            service = .web; label = host
            title = host + (url.path == "/" ? "" : url.path)
            titleFromPath = false
        }
    }
}

public extension Clip {
    var linkPresentation: LinkPresentation? { kind == .link ? LinkPresentation(text) : nil }
    var displayTitle: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        if let linkPresentation { return linkPresentation.title }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Whitespace" : title
    }
}

public extension Clip {
    /// Only native app identity establishes the source of otherwise plain text.
    var aiSourceService: LinkPresentation.Service? {
        guard kind == .text else { return nil }
        switch sourceBundle {
        case "com.openai.chat": return .chatgpt
        case "com.anthropic.claudefordesktop": return .claude
        case "com.openai.codex": return .codex
        case "com.todesktop.230313mzl4w4u92": return .cursor
        default: return nil
        }
    }
}
