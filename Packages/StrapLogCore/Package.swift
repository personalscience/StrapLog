// swift-tools-version: 6.0
// StrapLogCore: domain model, storage (GRDB), recording session. macOS-buildable so `swift test` needs no simulator.
import PackageDescription

let package = Package(
    name: "StrapLogCore",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [.library(name: "StrapLogCore", targets: ["StrapLogCore"])],
    dependencies: [
        .package(path: "../HRVKit"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.9.0"),
    ],
    targets: [
        .target(
            name: "StrapLogCore",
            dependencies: ["HRVKit", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(name: "StrapLogCoreTests", dependencies: ["StrapLogCore"]),
    ]
)
