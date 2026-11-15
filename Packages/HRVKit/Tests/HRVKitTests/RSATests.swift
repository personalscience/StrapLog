import Foundation
import Testing
@testable import HRVKit

/// Synthetic checks of the RSA metrics (straplog-9fr.2).
@Suite("RSA metrics, synthetic")
struct RSATests {
    static let period = 10.0   // 6/min

    /// HR samples about one per beat from `hr(t)`, starting at 0, for `seconds`.
    static func beats(seconds: Double, hr: (Double) -> Double) -> [TimedSample<Double>] {
        var t = 0.0, out: [TimedSample<Double>] = []
        while t < seconds {
            let v = hr(t)
            out.append(TimedSample(t: t, value: v))
            t += 60 / v
        }
        return out
    }

    /// 60 bpm rising 0.05 bpm/s, swing 10 bpm peaking 0.3 of the way into each breath.
    static func sinusoid(_ t: Double) -> Double {
        60 + 0.05 * t + 5 * cos(2 * .pi * (t / period - 0.3))
    }

    @Test("a sinusoid on a ramp: swing within 2%, peak within 0.02 breath, sync > 0.95")
    func sinusoidOnRamp() throws {
        var noise = SeededGaussian(seed: 7)
        let samples = Self.beats(seconds: 60) { Self.sinusoid($0) + 0.3 * noise.next() }
        let fit = try #require(Cosinor.fit(samples, periodS: Self.period, fromS: 10))
        #expect(abs(fit.swing - 10) / 10 < 0.02)
        #expect(abs(fit.peakFraction - 0.3) < 0.02)
        #expect(fit.sync > 0.95)
        #expect(abs(fit.slope - 0.05) < 0.01)
    }

    @Test("the peak fraction wraps into [0, 1)")
    func peakWraps() throws {
        let samples = Self.beats(seconds: 40) { 60 + 5 * cos(2 * .pi * ($0 / Self.period - 0.95)) }
        let fit = try #require(Cosinor.fit(samples, periodS: Self.period, fromS: 0))
        #expect(abs(fit.peakFraction - 0.95) < 0.01)
    }

    @Test("white noise has no sync")
    func whiteNoise() throws {
        var noise = SeededGaussian(seed: 11)
        let samples = Self.beats(seconds: 40) { _ in 60 + 3 * noise.next() }
        let fit = try #require(Cosinor.fit(samples, periodS: Self.period, fromS: 0))
        #expect(fit.sync < 0.2)
    }

    @Test("an ectopic pair is dropped by the cleaner and barely moves the swing")
    func ectopicPair() throws {
        let clean = Self.beats(seconds: 60) { Self.sinusoid($0) }
        var rr = clean.map { 60000 / $0.value }
        rr[30] *= 0.6; rr[31] *= 1.4   // premature beat, compensatory pause
        var tEnd: [Double] = [], t = 0.0
        for r in rr { t += r / 1000; tEnd.append(t) }

        let cleaned = InstantHR.samples(rrMs: rr, tEndS: tEnd)
        #expect(cleaned.count == rr.count - 2)
        let raw = zip(rr, tEnd).map { TimedSample(t: $1 - $0 / 2000, value: 60000 / $0) }
        let base = try #require(Cosinor.fit(Array(raw.indices).filter { $0 != 30 && $0 != 31 }.map { raw[$0] },
                                            periodS: Self.period, fromS: 10))
        let fit = try #require(Cosinor.fit(cleaned, periodS: Self.period, fromS: 10))
        #expect(abs(fit.swing - base.swing) / base.swing < 0.05)
    }

    @Test("instant HR sits at the middle of each kept interval")
    func instantHR() {
        let s = InstantHR.samples(rrMs: [1000, 1000, 800], tEndS: [1, 2, 2.8])
        #expect(s.map(\.t) == [0.5, 1.5, 2.4])
        #expect(s.map(\.value) == [60, 60, 75])
    }

    @Test("a breath's swing is max − min")
    func breathSwing() {
        let b = BreathSwing([60, 64, 58, 61, 63].enumerated().map { TimedSample(t: Double($0) * 2 + 0.5, value: $1) },
                            startS: 0, endS: 10)
        #expect(b.swing == 6)
        #expect(b.beats == 5)
    }

    @Test("a breath with a hole over 3 s or under 4 beats has no swing")
    func breathInvalid() {
        let hole = BreathSwing([0.5, 1.5, 2.5, 6.0, 7.0, 8.0, 9.0].map { TimedSample(t: $0, value: 60 + $0) },
                               startS: 0, endS: 10)
        #expect(hole.swing == nil)
        let edgeHole = BreathSwing([0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5].map { TimedSample(t: $0, value: 60 + $0) },
                                   startS: 0, endS: 10)
        #expect(edgeHole.swing == nil)
        let sparse = BreathSwing([1.0, 3.5, 6.0].map { TimedSample(t: $0, value: 60) }, startS: 0, endS: 7.5)
        #expect(sparse.swing == nil)
        #expect(sparse.beats == 3)
    }

    @Test("a window with too few samples or too many holes has no fit")
    func fitGates() {
        let sparse = Self.beats(seconds: 40) { _ in 6 }   // one sample every 10 s
        #expect(Cosinor.fit(sparse, periodS: Self.period, fromS: 0) == nil)
        let full = Self.beats(seconds: 40) { Self.sinusoid($0) }
        let holed = full.filter { !(5..<17).contains($0.t) }   // 12 s hole in 40 s
        #expect(Cosinor.fit(holed, periodS: Self.period, fromS: 0) == nil)
        let flat = Self.beats(seconds: 40) { _ in 60 }
        #expect(Cosinor.fit(flat, periodS: Self.period, fromS: 0) == nil)
    }
}
