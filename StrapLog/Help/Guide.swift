import Foundation

/// The bundled metrics guide, parsed once.
enum Guide {
    static let resourceName = "MetricsGuide"

    static let blocks: [GuideBlock] = load(from: .main)

    /// Parsed `MetricsGuide.md`, or a one-paragraph explanation if the resource is missing.
    static func load(from bundle: Bundle) -> [GuideBlock] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [.paragraph("The guide is missing from this build.")]
        }
        return GuideParser.parse(text)
    }
}
