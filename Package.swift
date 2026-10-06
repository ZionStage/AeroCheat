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
        // Menu bar app: status item, global hotkey, floating panel.
        .executableTarget(name: "AeroCheat", dependencies: ["AeroCheatCore"]),
        .testTarget(
            name: "AeroCheatCoreTests",
            dependencies: ["AeroCheatCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
