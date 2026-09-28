import Foundation

/// Installed apps carry resources in Contents/Resources. SwiftPM executables use
/// the generated module bundle, which is only available in a development build.
/// A missing optional icon in an installed app must not consult that build path.
enum BundledResources {
    static let bundle: Bundle =
        Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main : Bundle.module
}
