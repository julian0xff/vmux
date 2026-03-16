// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VmuxSession",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VmuxSession", targets: ["VmuxSession"]),
    ],
    dependencies: [
        .package(path: "../VmuxCore"),
        .package(path: "../../vendor/bonsplit"),
    ],
    targets: [
        .target(
            name: "VmuxSession",
            dependencies: [
                "VmuxCore",
                .product(name: "Bonsplit", package: "bonsplit"),
            ],
            path: "Sources/VmuxSession"
        ),
    ]
)
