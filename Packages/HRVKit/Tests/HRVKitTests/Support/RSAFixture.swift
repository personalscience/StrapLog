import Foundation
import HRVKit

/// `Tests/fixtures/rsa-calibration.json`, written by `tools/gen_rsa_fixture.py`:
/// chest beats from the 261115 calibration session with the pacer steps and Python
/// reference numbers (numpy cosinor, per-breath max − min).
struct RSAFixture: Decodable {
    struct Constants: Decodable {
        let window_breaths: Int
        let min_beats_per_breath: Int
        let max_hole_ms: Double
        let pct_thresh: Double
        let clean_iterations: Int
    }

    struct BreathRef: Decodable {
        let breaths_per_minute: Double
        let t0_ms: Double
        let virtual: Bool
        var periodS: Double { 60 / breaths_per_minute }
    }

    struct Fit: Decodable {
        let from_ms: Double
        let to_ms: Double
        let n: Int
        let mean_bpm: Double
        let slope_bpm_per_s: Double
        let swing_bpm: Double
        let sync: Double
        let peak_fraction: Double
    }

    struct Breath: Decodable {
        let from_ms: Double
        let to_ms: Double
        let n: Int
        let swing_bpm: Double?
    }

    struct Cosinor: Decodable {
        let whole: Fit?
        let median_swing_bpm: Double?
        let windows: [Fit]
    }

    struct Reference: Decodable {
        let from_ms: Double
        let to_ms: Double
        let cosinor: Cosinor
        let breaths: [Breath]
    }

    struct Step: Decodable {
        let label: String
        let from_ms: Double
        let to_ms: Double
        let breath_ref: BreathRef
        let reference: Reference
    }

    let constants: Constants
    let t_end_ms: [Double]
    let rr_ms: [Double]
    let removed_indices: [Int]
    let steps: [Step]

    static func load() throws -> RSAFixture {
        let data = try Data(contentsOf: Fixture.directory.appending(path: "rsa-calibration.json"))
        return try JSONDecoder().decode(RSAFixture.self, from: data)
    }

    var samples: [TimedSample<Double>] {
        InstantHR.samples(rrMs: rr_ms, tEndS: t_end_ms.map { $0 / 1000 })
    }

    func step(_ label: String) -> Step { steps.first { $0.label == label }! }

    /// Every run of `RSADefaults.windowBreaths` whole breaths of `periodS`, stride one breath,
    /// aligned to `t0S`, inside [fromS, toS): what the live tracker would fit.
    static func windows(fromS: Double, toS: Double, t0S: Double, periodS: Double) -> [Double] {
        let span = Double(RSADefaults.windowBreaths) * periodS
        var start = t0S + ((fromS - t0S) / periodS).rounded(.up) * periodS
        var out: [Double] = []
        while start + span <= toS + 1e-9 { out.append(start); start += periodS }
        return out
    }
}

extension Array where Element == Double {
    var median: Double? {
        guard !isEmpty else { return nil }
        let s = sorted(), m = count / 2
        return count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
    }
}
