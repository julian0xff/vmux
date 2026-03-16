// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vmux",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "vmux", targets: ["vmux"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "vmux",
            dependencies: ["SwiftTerm"],
            path: "Sources"
        )
    ]
)
