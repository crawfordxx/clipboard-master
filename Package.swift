// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClipboardMaster",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClipboardMasterCore"),
        .executableTarget(
            name: "ClipboardMasterApp",
            dependencies: ["ClipboardMasterCore"]
        ),
        .testTarget(name: "ClipboardMasterAppTests", dependencies: ["ClipboardMasterApp"]),
        .testTarget(
            name: "ClipboardMasterCoreTests",
            dependencies: ["ClipboardMasterCore"]
        ),
    ]
)
