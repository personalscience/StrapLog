import Foundation
@testable import StrapLogCore

/// The beats and pacer steps of `Tests/fixtures/rsa-calibration.json` (`tools/gen_rsa_fixture.py`),
/// as the live tracker sees them. HRVKit's `RSAFixtureTests` checks the metrics themselves.
struct RSAFixture: Decodable {
    struct BreathRef: Decodable {
        let breaths_per_minute: Double
        let t0_ms: Double
        let virtual: Bool
    }

    struct Breath: Decodable {
        let from_ms: Double
        let swing_bpm: Double?
    }

    struct Reference: Decodable {
        let breaths: [Breath]
    }

    struct Step: Decodable {
        let label: String
        let from_ms: Double
        let to_ms: Double
        let breath_ref: BreathRef
        let reference: Reference

        var pacer: BreathingPacer {
            BreathingPacer(breathsPerMinute: breath_ref.breaths_per_minute, startedAtMs: Int64(breath_ref.t0_ms))
        }
    }

    let t_end_ms: [Double]
    let rr_ms: [Double]
    let steps: [Step]

    static func load() throws -> RSAFixture {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../../Tests/fixtures/rsa-calibration.json").standardized
        return try JSONDecoder().decode(RSAFixture.self, from: Data(contentsOf: url))
    }

    func step(_ label: String) -> Step { steps.first { $0.label == label }! }

    /// Beats ending in [fromMs, toMs), as `TimedBeat` end times and RR.
    func beats(fromMs: Int64, toMs: Int64) -> [(tEndMs: Int64, rrMs: Double)] {
        zip(t_end_ms, rr_ms).map { (Int64($0), $1) }.filter { fromMs <= $0.0 && $0.0 < toMs }
    }
}
