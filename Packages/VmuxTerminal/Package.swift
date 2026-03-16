// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxTerminal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxTerminal", targets: ["VmuxTerminal"]),
    ],
    dependencies: [
        .package(path: "../VmuxCore"),
    ],
    targets: [
        .target(
            name: "VmuxTerminal",
            dependencies: [
                "VmuxCore",
            ],
            path: "Sources/VmuxTerminal"
        ),
    ]
)
