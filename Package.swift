// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Stash", platforms: [.macOS(.v14)], products: [.executable(name: "Stash", targets: ["Stash"])], targets: [.target(name: "StashCore"), .executableTarget(name: "Stash", dependencies: ["StashCore"], resources: [.copy("Resources/CategoryArt"), .copy("Resources/ServiceIcons")]), .executableTarget(name: "StashCoreChecks", dependencies: ["StashCore"], path: "Tests/StashCoreTests")])
