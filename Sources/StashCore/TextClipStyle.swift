import Foundation

/// Presentation only: content stays plain text and retains its original payload.
public enum TextClipStyle: String {
    case json, command, code

    public var symbol: String {
        switch self {
        case .json: return "curlybraces"
        case .command: return "terminal"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public static func detect(_ text: String) -> Self? {
        // Bound parsing work when rendering long clipboard items.
        guard text.utf8.count <= 65_536 else { return nil }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (value.hasPrefix("{") || value.hasPrefix("[")),
           let data = value.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil { return .json }

        let lines = value.components(separatedBy: .newlines)
        let shells: Set<String> = ["sh", "bash", "zsh", "shell", "console"]
        if lines.count >= 3, lines.first?.hasPrefix("```") == true, lines.last == "```" {
            let language = String(lines[0].dropFirst(3)).lowercased()
            if shells.contains(language) { return .command }
            let languages: Set<String> = ["swift", "python", "py", "javascript", "js", "typescript", "ts", "tsx", "jsx", "go", "rust", "java", "c", "cpp", "csharp", "ruby", "sql", "html", "css", "json", "yaml"]
            if languages.contains(language) { return .code }
        }
        if value.hasPrefix("#!/bin/sh\n") || value.hasPrefix("#!/bin/bash\n") || value.hasPrefix("#!/usr/bin/env bash\n") { return .command }
        // Require an explicit prompt plus a known executable; never run the text.
        if lines.count == 1, value.hasPrefix("$ ") || value.hasPrefix("% ") {
            let executable = value.dropFirst(2).split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
            let commands: Set<String> = ["git", "npm", "npx", "pnpm", "yarn", "bun", "python", "python3", "pip", "pip3", "swift", "cargo", "go", "docker", "kubectl", "curl", "wget", "brew", "ssh", "ls", "cd", "mkdir", "cat", "rg"]
            if let executable, commands.contains(executable) { return .command }
        }
        return nil
    }
}

public extension Clip {
    var textStyle: TextClipStyle? { kind == .text ? TextClipStyle.detect(text) : nil }
}
