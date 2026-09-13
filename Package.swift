// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClipHistory",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipHistoryCore"),
        .executableTarget(
            name: "ClipHistoryApp",
            dependencies: ["ClipHistoryCore"]
        ),
        .testTarget(
            name: "ClipHistoryCoreTests",
            dependencies: ["ClipHistoryCore"]
        ),
    ]
)
