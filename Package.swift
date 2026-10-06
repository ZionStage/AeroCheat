// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AeroCheat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AeroCheat", targets: ["AeroCheat"]),
    ],
    targets: [
        // Parsing and filtering logic, free of any UI dependency.
        .target(name: "AeroCheatCore"),
        // The suggestion bubble: its style value type, geometry and SwiftUI view. A library so tests can
        // render it offscreen.
        .target(name: "AeroCheatUI", dependencies: ["AeroCheatCore"]),
        // Menu bar app: status item, global hotkey, floating panel.
        .executableTarget(name: "AeroCheat", dependencies: ["AeroCheatCore", "AeroCheatUI"]),
        .testTarget(
            name: "AeroCheatCoreTests",
            dependencies: ["AeroCheatCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "AeroCheatUITests", dependencies: ["AeroCheatUI", "AeroCheatCore"]),
    ]
)
