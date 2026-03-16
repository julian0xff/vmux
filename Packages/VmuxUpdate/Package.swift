// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxUpdate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxUpdate", targets: ["VmuxUpdate"]),
    ],
    dependencies: [
        .package(path: "../VmuxCore"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.0"),
    ],
    targets: [
        .target(
            name: "VmuxUpdate",
            dependencies: ["VmuxCore", "Sparkle"],
            path: "Sources/VmuxUpdate"
        ),
    ]
)
