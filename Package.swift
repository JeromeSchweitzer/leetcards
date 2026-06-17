// swift-tools-version: 6.2
import PackageDescription

// SwiftPM manifest for the macOS build + CLI tests (`swift build`, `swift test`,
// `swift run`). The iOS target and the app bundle still come from the XcodeGen
// project (`project.yml` -> LeetCards.xcodeproj); SwiftPM builds the macOS host
// only. Both build systems compile the same sources in App/ and Tests/.
//
// The `SWIFTPM` define lets shared code locate the bundled dataset via
// `Bundle.module` here while the Xcode build uses `Bundle.main` (see
// DatasetProvider.swift).
let package = Package(
    name: "LeetCards",
    platforms: [.macOS(.v26), .iOS(.v26)],
    targets: [
        .executableTarget(
            name: "LeetCards",
            path: "App",
            resources: [.process("Resources")],
            swiftSettings: [.define("SWIFTPM")]
        ),
        .testTarget(
            name: "LeetCardsTests",
            dependencies: ["LeetCards"],
            path: "Tests",
            swiftSettings: [.define("SWIFTPM")]
        ),
    ]
)
