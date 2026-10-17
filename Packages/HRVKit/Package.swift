// swift-tools-version: 6.0
// HRVKit: pure Swift HRV algorithms. No I/O, no UI, no third-party dependencies.
import PackageDescription

let package = Package(
    name: "HRVKit",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11)],
    products: [.library(name: "HRVKit", targets: ["HRVKit"])],
    targets: [
        .target(name: "HRVKit"),
        .testTarget(name: "HRVKitTests", dependencies: ["HRVKit"]),
    ]
)
