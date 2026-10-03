import Foundation

/// Reads and writes the macOS Screenshot app's own preferences.
public enum ScreenshotPreferences {
    private static let domain = "com.apple.screencapture" as CFString
    private static let thumbnailKey = "show-thumbnail" as CFString

    /// macOS holds the file back while the floating thumbnail is visible (about five seconds),
    /// so Stash cannot copy a screenshot until it disappears. On by default.
    public static var showsFloatingThumbnail: Bool {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(thumbnailKey, domain) as? Bool ?? true
    }

    /// Same switch as ⇧⌘5 → Options → Show Floating Thumbnail; applies to the next capture.
    @discardableResult public static func hideFloatingThumbnail() -> Bool {
        CFPreferencesSetAppValue(thumbnailKey, kCFBooleanFalse, domain)
        return CFPreferencesAppSynchronize(domain) && !showsFloatingThumbnail
    }
}
