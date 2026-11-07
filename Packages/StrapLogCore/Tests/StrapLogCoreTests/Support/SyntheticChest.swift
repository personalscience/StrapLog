import Foundation
@testable import StrapLogCore

/// A strap on a breathing chest at 25 Hz, in 10-sample notifications: gravity, plus a swing of
/// `amplitudeMg` peak to peak along `axis` that follows `lung` (0 empty, 1 full, by ms), plus
/// seeded noise of about ±`noiseMg`.
struct SyntheticChest {
    static let hz = 25.0
    var gravity = SIMD3<Double>(200, 100, 970)
    var axis = SIMD3<Double>(1, 0, 0.3)
    var amplitudeMg = 70.0
    var noiseMg = 3.0
    var lung: (Int64) -> Double

    /// Notifications covering `fromMs` up to `toMs`.
    func notifications(fromMs: Int64, toMs: Int64) -> [(atMs: Int64, samples: [AccSample])] {
        var noise = UInt64(fromMs & 0xFFFF) | 1
        let unit = axis / (axis * axis).sum().squareRoot()
        let periodMs = 1000 / Self.hz
        var out: [(atMs: Int64, samples: [AccSample])] = []
        var batch: [AccSample] = []
        var i = 0
        while true {
            let t = Double(fromMs) + Double(i) * periodMs
            if t >= Double(toMs) { break }
            let v = gravity + unit * (amplitudeMg * (lung(Int64(t)) - 0.5))
            func jitter() -> Int {
                noise = noise &* 6364136223846793005 &+ 1442695040888963407
                return Int(Double(noise >> 54) / 1024 * 2 * noiseMg - noiseMg)
            }
            batch.append(AccSample(deviceNs: UInt64(t * 1_000_000), x: Int(v.x.rounded()) + jitter(),
                                   y: Int(v.y.rounded()) + jitter(), z: Int(v.z.rounded()) + jitter()))
            if batch.count == 10 {
                out.append((Int64(t.rounded()), batch))
                batch = []
            }
            i += 1
        }
        return out
    }
}
