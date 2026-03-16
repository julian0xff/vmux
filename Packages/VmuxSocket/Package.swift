// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxSocket",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxSocket", targets: ["VmuxSocket"]),
    ],
    dependencies: [
        .package(path: "../VmuxCore"),
    ],
    targets: [
        .target(
            name: "VmuxSocket",
            dependencies: ["VmuxCore"],
            path: "Sources/VmuxSocket"
        ),
    ]
)
