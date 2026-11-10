// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NiceSwitcherProbe",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ProbeCore", targets: ["ProbeCore"]),
        .library(name: "NiceSwitcherCore", targets: ["NiceSwitcherCore"]),
        .executable(name: "NiceSwitcherProbe", targets: ["NiceSwitcherProbe"])
    ],
    targets: [
        .target(name: "ProbeCore"),
        .target(name: "NiceSwitcherCore"),
        .executableTarget(name: "NiceSwitcherProbe", dependencies: ["ProbeCore"]),
        .testTarget(name: "ProbeCoreTests", dependencies: ["ProbeCore"]),
        .testTarget(name: "NiceSwitcherCoreTests", dependencies: ["NiceSwitcherCore"])
    ]
)
