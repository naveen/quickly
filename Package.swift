// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Quickly",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure-Foundation logic: scanning, matching, usage ranking, timezone parsing.
        .target(name: "QuicklyCore"),
        // The AppKit app: panel UI, hotkey, status item, commands.
        .executableTarget(
            name: "Quickly",
            dependencies: ["QuicklyCore"],
            linkerSettings: [.linkedFramework("Carbon"), .linkedFramework("ServiceManagement")]
        ),
        .testTarget(name: "QuicklyCoreTests", dependencies: ["QuicklyCore"]),
    ],
    swiftLanguageVersions: [.v5]
)
