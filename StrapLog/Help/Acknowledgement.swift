import Foundation

/// Third-party software shipped inside the app, with the copyright line and license text each one asks us to carry.
/// The texts are verbatim copies in `Resources/Licenses/`, refreshed by hand when a package's license changes.
struct Acknowledgement: Identifiable, Hashable {
    let name: String
    let copyright: String
    let license: String
    /// Basename of the bundled `.txt` holding the full license.
    let resourceName: String

    var id: String { name }

    /// Every package linked into the app, including the Polar SDK's own dependencies.
    static let all: [Acknowledgement] = [
        Acknowledgement(name: "Polar BLE SDK", copyright: "Copyright © Polar Electro Oy. All rights reserved.",
                        license: "Polar SDK License Agreement", resourceName: "PolarBleSdk"),
        Acknowledgement(name: "GRDB.swift", copyright: "Copyright © 2015-2025 Gwendal Roué",
                        license: "MIT License", resourceName: "GRDB"),
        Acknowledgement(name: "SwiftProtobuf", copyright: "Copyright © Apple Inc. and the SwiftProtobuf project authors",
                        license: "Apache License 2.0 with Runtime Library Exception", resourceName: "SwiftProtobuf"),
        Acknowledgement(name: "Zip", copyright: "Copyright © 2015 Roy Marmelstein",
                        license: "MIT License", resourceName: "Zip"),
    ]

    /// The full license text, or nil if the resource is missing from `bundle`.
    func licenseText(in bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
