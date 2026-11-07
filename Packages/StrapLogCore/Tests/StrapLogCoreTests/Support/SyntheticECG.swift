import Foundation
@testable import StrapLogCore

/// A clean-ish single-lead ECG at 130 Hz: a sharp R (with small Q and S dips), a broad T wave a
/// third its height, baseline wander and seeded noise. `beatsMs` are where the R peaks are.
struct SyntheticECG {
    static let hz = 130.0
    let beatsMs: [Double]
    let samples: [EcgSample]

    /// `rrMs` between beats, starting `firstBeatMs` in; strap clock starts at `startNs`.
    init(rrMs: [Double], firstBeatMs: Double = 400, polarity: Double = 1, startNs: UInt64 = 7_000_000_000_000) {
        var beats = [firstBeatMs]
        for rr in rrMs { beats.append(beats.last! + rr) }
        beatsMs = beats
        var noise = UInt64(42)
        let count = Int((beats.last! + 600) / 1000 * Self.hz)
        samples = (0..<count).map { i in
            let t = Double(i) * 1000 / Self.hz
            var v = 200 * sin(2 * .pi * 0.3 * t / 1000)
            for b in beats {
                let d = t - b
                v += polarity * (1000 * exp(-d * d / (2 * 12 * 12))
                    - 150 * exp(-(d + 25) * (d + 25) / (2 * 8 * 8))
                    - 200 * exp(-(d - 25) * (d - 25) / (2 * 8 * 8))
                    + 300 * exp(-(d - 250) * (d - 250) / (2 * 40 * 40)))
            }
            noise = noise &* 6364136223846793005 &+ 1442695040888963407
            v += Double(Int(noise >> 59)) * 2.5 - 20
            return EcgSample(deviceNs: startNs + UInt64(t * 1_000_000), microvolts: Int(v.rounded()))
        }
    }
}
