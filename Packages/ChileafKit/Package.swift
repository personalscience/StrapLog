// swift-tools-version: 6.0
// ChileafKit: decodes what the Chileaf CL831 armband (sold with BaroShift as "CL837-…") notifies
// and turns it into StrapLogCore sensor events. Bytes in, events out: no CoreBluetooth, no I/O,
// nothing ever written to the band.
import PackageDescription

let package = Package(
    name: "ChileafKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "ChileafKit", targets: ["ChileafKit"])],
    dependencies: [.package(path: "../StrapLogCore")],
    targets: [
        .target(name: "ChileafKit", dependencies: ["StrapLogCore"]),
        .testTarget(name: "ChileafKitTests", dependencies: ["ChileafKit"]),
    ]
)
