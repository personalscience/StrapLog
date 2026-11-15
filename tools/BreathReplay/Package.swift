// swift-tools-version: 6.0
// breath-replay: runs recorded accelerometer samples through StrapLogCore's own BreathTracker,
// so offline analysis (tools/arm_breath_replay.py) scores the exact code the apps run.
import PackageDescription

let package = Package(
    name: "BreathReplay",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "../../Packages/StrapLogCore")],
    targets: [
        .executableTarget(name: "BreathReplay", dependencies: ["StrapLogCore"]),
    ]
)
