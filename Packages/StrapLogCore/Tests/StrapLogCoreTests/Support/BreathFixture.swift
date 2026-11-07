import Foundation
@testable import StrapLogCore

/// A stretch of per-second gravity and the pacer over it, from a repo-root
/// `Tests/fixtures/<name>.json` (written by `tools/gen_breath_fixture.py`).
struct BreathFixture: Decodable {
    struct Pacer: Decodable {
        let breaths_per_minute: Double
        let t0_ms: Int64
    }

    let pacer: Pacer
    let second_ms: [Int64]
    let gx_mg: [Int]
    let gy_mg: [Int]
    let gz_mg: [Int]

    static func load(_ name: String) throws -> BreathFixture {
        try JSONDecoder().decode(BreathFixture.self, from: Data(contentsOf: RRFixture.url(name)))
    }

    var breathingPacer: BreathingPacer {
        BreathingPacer(breathsPerMinute: pacer.breaths_per_minute, startedAtMs: pacer.t0_ms)
    }

    /// Each second as a one-sample notification received at its midpoint.
    var notifications: [(atMs: Int64, samples: [AccSample])] {
        second_ms.indices.map { i in
            (second_ms[i] + 500, [AccSample(deviceNs: 0, x: gx_mg[i], y: gy_mg[i], z: gz_mg[i])])
        }
    }
}
