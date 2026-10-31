// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidOnce",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LidOnce", targets: ["LidOnce"]),
        .executable(name: "LidOnceAgent", targets: ["LidOnceAgent"])
    ],
    targets: [
        .target(name: "LidOnceCore"),
        .target(name: "LidOnceSystem", dependencies: ["LidOnceCore"]),
        .executableTarget(name: "LidOnce", dependencies: ["LidOnceCore", "LidOnceSystem"]),
        .executableTarget(name: "LidOnceAgent", dependencies: ["LidOnceCore", "LidOnceSystem"]),
        .testTarget(name: "LidOnceCoreTests", dependencies: ["LidOnceCore"])
    ]
)
