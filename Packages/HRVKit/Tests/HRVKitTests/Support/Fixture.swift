import Foundation
import HRVKit

/// A parity fixture written by `tools/gen_fixtures.py` from analyze_h10.py output.
struct Fixture: Decodable {
    struct Constants: Decodable {
        let window_s: Double
        let stride_s: Double
        let pct_thresh: Double
        let min_beats_per_window: Int
        let dfa_scale_min: Int
        let dfa_scale_max: Int
    }

    struct Clean: Decodable {
        let removed_indices: [Int]
        let n_clean: Int
        let rmssd_ms: Double
        let sdnn_ms: Double
        let mean_hr_bpm: Double
        let alpha1: Double?
    }

    struct Window: Decodable {
        let t_center_s: Double
        let n_raw: Int
        let n_beats: Int
        let hr_bpm: Double
        let rmssd_ms: Double?
        let sdnn_ms: Double
        let alpha1: Double?
    }

    let constants: Constants
    let t_rel_s: [Double]
    let rr_ms: [Double]
    let clean: Clean
    let windows: [Window]

    static let names = ["resting", "strength", "overnight"]

    /// Repo-root `Tests/fixtures/`, located from this source file.
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // HRVKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // HRVKit
        .deletingLastPathComponent()   // Packages
        .deletingLastPathComponent()   // repo root
        .appending(path: "Tests/fixtures")

    static func load(_ name: String) throws -> Fixture {
        let data = try Data(contentsOf: directory.appending(path: "\(name).json"))
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    var beats: [TimedSample<Double>] {
        zip(t_rel_s, rr_ms).map { TimedSample(t: $0, value: $1) }
    }
}
