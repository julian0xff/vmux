// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxCore", targets: ["VmuxCore"]),
    ],
    targets: [
        .target(
            name: "VmuxCore",
            dependencies: [],
            path: "Sources/VmuxCore"
        ),
    ]
)
