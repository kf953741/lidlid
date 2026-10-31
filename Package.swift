// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidOnce",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LidOnce", targets: ["LidOnce"])],
    targets: [
        .target(name: "LidOnceCore"),
        .executableTarget(name: "LidOnce", dependencies: ["LidOnceCore"]),
        .testTarget(name: "LidOnceCoreTests", dependencies: ["LidOnceCore"])
    ]
)
