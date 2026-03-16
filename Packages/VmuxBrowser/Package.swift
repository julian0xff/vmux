// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxBrowser",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxBrowser", targets: ["VmuxBrowser"]),
    ],
    dependencies: [
        .package(path: "../VmuxCore"),
        .package(path: "../VmuxTerminal"),
    ],
    targets: [
        .target(
            name: "VmuxBrowser",
            dependencies: [
                "VmuxCore",
                "VmuxTerminal",
            ],
            path: "Sources/VmuxBrowser"
        ),
    ]
)
