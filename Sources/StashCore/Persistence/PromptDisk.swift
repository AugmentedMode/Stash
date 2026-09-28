import Foundation

public enum PromptDisk {
    public static func load(from url: URL) throws -> [SavedPrompt] {
        try PrivateJSONStore.load(from: url, default: [])
    }

    public static func save(_ prompts: [SavedPrompt], to url: URL) throws {
        try PrivateJSONStore.save(prompts, to: url)
    }
}
