import Foundation
import AppKit

public enum ClipKind: String, Codable, CaseIterable {
    case text, link, email, color, image, screenshot, video, file
    public var title: String {
        switch self {
        case .text: return "Text"

        case .link: return "Links"

        case .email: return "Emails"

        case .color: return "Colors"

        case .image: return "Images"

        case .screenshot: return "Screenshots"

        case .video: return "Videos"

        case .file: return "Files"
        }
    }
    public var symbol: String {
        switch self {
        case .text: return "text.alignleft"

        case .link: return "link"

        case .email: return "at"

        case .color: return "paintpalette"

        case .image: return "photo"

        case .screenshot: return "camera.viewfinder"

        case .video: return "play.rectangle"

        case .file: return "doc"
        }
    }
    public static func classify(_ value: String) -> ClipKind {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: "^#(?:[A-Fa-f0-9]{3}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$", options: .regularExpression)
            != nil
        {
            return .color
        }
        if s.range(
            of: "^[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}$",
            options: [.regularExpression, .caseInsensitive]) != nil
        {
            return .email
        }
        if let url = URL(string: s), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil, !s.contains(where: { $0.isWhitespace })
        {
            return .link
        }
        return .text
    }
}
