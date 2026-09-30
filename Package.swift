// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Stash", targets: ["Stash"])
    ],
    dependencies: [
        // Update checks only. Pinned so every release ships an audited version.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "StashCore"),
        .executableTarget(
            name: "Stash",
            dependencies: ["StashCore", .product(name: "Sparkle", package: "Sparkle")],
            resources: [.copy("Resources/CategoryArt"), .copy("Resources/ServiceIcons")]
        ),
        // Named pasteboard integration checks also run with Command Line Tools,
        // where XCTest is not necessarily available.
        .executableTarget(
            name: "StashCoreChecks",
            dependencies: ["StashCore"],
            path: "Tests/StashCoreTests"
        ),
    ]
)
