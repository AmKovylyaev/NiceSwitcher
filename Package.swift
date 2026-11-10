// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NiceSwitcherProbe",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ProbeCore", targets: ["ProbeCore"]),
        .executable(name: "NiceSwitcherProbe", targets: ["NiceSwitcherProbe"])
    ],
    targets: [
        .target(name: "ProbeCore"),
        .executableTarget(name: "NiceSwitcherProbe", dependencies: ["ProbeCore"]),
        .testTarget(name: "ProbeCoreTests", dependencies: ["ProbeCore"])
    ]
)
