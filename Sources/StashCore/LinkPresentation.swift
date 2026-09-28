import Foundation

/// Offline display metadata only. Never substitutes for the original URL payload.
public struct LinkPresentation: Equatable {
    public enum Service: String { case notion, github, figma, docs, sheets, slides, web }
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
        if let linkPresentation { return linkPresentation.title }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Whitespace" : title
    }
}
