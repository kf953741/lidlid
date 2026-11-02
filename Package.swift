// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidOnce",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LidOnce", targets: ["LidOnce"]),
        .executable(name: "LidOnceAgent", targets: ["LidOnceAgent"]),
        .executable(name: "LidLidCompatibility", targets: ["LidLidCompatibility"]),
        .executable(name: "LidLidSleepService", targets: ["LidLidSleepService"])
    ],
    targets: [
        .target(name: "LidOnceCore"),
        .target(name: "LidLidServiceCore"),
        .target(name: "LidLidServiceProtocol"),
        .target(name: "LidOnceSystem", dependencies: ["LidOnceCore", "LidLidServiceProtocol"]),
        .executableTarget(name: "LidOnce", dependencies: ["LidOnceCore", "LidOnceSystem"]),
        .executableTarget(name: "LidOnceAgent", dependencies: ["LidOnceCore", "LidOnceSystem", "LidLidServiceProtocol"]),
        .executableTarget(name: "LidLidCompatibility", dependencies: ["LidOnceCore", "LidOnceSystem", "LidLidServiceProtocol"]),
        .executableTarget(name: "LidLidSleepService", dependencies: ["LidLidServiceCore", "LidLidServiceProtocol", "LidOnceSystem"]),
        .testTarget(name: "LidOnceCoreTests", dependencies: ["LidOnceCore"]),
        .testTarget(name: "LidLidServiceTests", dependencies: ["LidLidServiceCore", "LidLidServiceProtocol"])
    ]
)
