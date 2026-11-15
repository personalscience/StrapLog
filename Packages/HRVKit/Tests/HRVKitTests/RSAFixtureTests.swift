import Foundation
import Testing
@testable import HRVKit

/// RSA metrics on the 261115 calibration session against gen_rsa_fixture.py
/// (straplog-9fr.2 acceptance).
@Suite("RSA fixture: 261115 calibration")
struct RSAFixtureTests {
    static let swingTolerance = 0.1

    @Test("fixture constants match RSADefaults and HRVDefaults")
    func constants() throws {
        let c = try RSAFixture.load().constants
        #expect(c.window_breaths == RSADefaults.windowBreaths)
        #expect(c.min_beats_per_breath == RSADefaults.minBeatsPerBreath)
        #expect(c.max_hole_ms / 1000 == RSADefaults.maxHoleSeconds)
        #expect(c.pct_thresh == HRVDefaults.pctThresh)
        #expect(c.clean_iterations == HRVDefaults.cleanIterations)
    }

    @Test("the cleaner drops the same beats")
    func cleaning() throws {
        let fx = try RSAFixture.load()
        #expect(RRCleaner().clean(fx.rr_ms).removedIndices == fx.removed_indices)
    }

    @Test("every 4-breath window matches the numpy cosinor")
    func windowParity() throws {
        let fx = try RSAFixture.load()
        let samples = fx.samples
        var compared = 0
        for step in fx.steps {
            for ref in step.reference.cosinor.windows {
                let fit = try #require(Cosinor.fit(samples, periodS: step.breath_ref.periodS, fromS: ref.from_ms / 1000),
                                       "\(step.label) @\(ref.from_ms)")
                expect(fit, matches: ref, "\(step.label) @\(ref.from_ms)")
                compared += 1
            }
        }
        #expect(compared > 50)
    }

    @Test("the whole-step fits match the numpy cosinor")
    func wholeParity() throws {
        let fx = try RSAFixture.load()
        let samples = fx.samples
        for step in fx.steps {
            guard let ref = step.reference.cosinor.whole else { continue }
            let period = step.breath_ref.periodS
            let breaths = Int(((ref.to_ms - ref.from_ms) / 1000 / period).rounded())
            let fit = try #require(Cosinor.fit(samples, periodS: period, fromS: ref.from_ms / 1000, breaths: breaths),
                                   "\(step.label)")
            expect(fit, matches: ref, step.label)
        }
    }

    @Test("per-breath max − min matches, including which breaths are invalid")
    func breathParity() throws {
        let fx = try RSAFixture.load()
        let samples = fx.samples
        for step in fx.steps {
            for ref in step.reference.breaths {
                let b = BreathSwing(samples, startS: ref.from_ms / 1000, endS: ref.to_ms / 1000)
                #expect(b.beats == ref.n, "\(step.label) @\(ref.from_ms)")
                switch (b.swing, ref.swing_bpm) {
                case (nil, nil): break
                case let (s?, r?): #expect(abs(s - r) < Self.swingTolerance, "\(step.label) @\(ref.from_ms)")
                default: Issue.record("\(step.label) @\(ref.from_ms): swift \(String(describing: b.swing)) vs \(String(describing: ref.swing_bpm))")
                }
            }
        }
    }

    @Test("median swing ranks 4.5 and 6 above 8 above 10 /min")
    func rateRanking() throws {
        let fx = try RSAFixture.load()
        func median(_ label: String) throws -> Double {
            try #require(fittedWindows(fx, fx.step(label)).map(\.swing).median)
        }
        let (r45, r6, r8, r10) = try (median("follow_4.5"), median("follow_6"), median("follow_8"), median("follow_10"))
        #expect(min(r45, r6) > r8)
        #expect(r8 > r10)
        #expect(r45 > 10 && r6 > 7)
    }

    /// A hold is 30 s; the 4-breath window that lies inside it (or nearly) shows how the
    /// live fit reads once the window has filled with held breath. Criterion (Rik, 2026-11-15):
    /// sync under 0.2 and swing under half the followed 6/min median, not an absolute bpm,
    /// because an absolute cutoff cannot tell a hold (3.1) from his 10/min breathing (3.2).
    @Test("a breath hold reads no sync and under half the followed swing", arguments: ["hold_1", "hold_2"])
    func holds(label: String) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label), ref = step.breath_ref
        let span = Double(RSADefaults.windowBreaths) * ref.periodS
        // The window starting at the first breath boundary inside the hold.
        let from = try #require(RSAFixture.windows(fromS: step.from_ms / 1000, toS: step.from_ms / 1000 + span + ref.periodS,
                                                   t0S: ref.t0_ms / 1000, periodS: ref.periodS).first)
        let fit = try #require(Cosinor.fit(fx.samples, periodS: ref.periodS, fromS: from))
        let followed = try #require(fittedWindows(fx, fx.step("follow_6")).map(\.swing).median)
        #expect(fit.swing < followed / 2)
        #expect(fit.sync < 0.2)
    }

    @Test("fitting the wrong rate gives low sync",
          arguments: [("follow_8", 6.0), ("follow_6", 8.0)])
    func wrongRate(label: String, rate: Double) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label)
        let wrong = 60 / rate
        let fits = RSAFixture.windows(fromS: step.reference.from_ms / 1000, toS: step.reference.to_ms / 1000,
                                      t0S: step.breath_ref.t0_ms / 1000, periodS: wrong)
            .compactMap { Cosinor.fit(fx.samples, periodS: wrong, fromS: $0) }
        #expect(!fits.isEmpty)
        #expect(try #require(fits.map(\.sync).median) < 0.3)
    }

    @Test("a pacer half a breath late: same swing and sync, peak moved half a breath",
          arguments: ["follow_6", "follow_4.5", "after_move"])
    func halfBreathShift(label: String) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label)
        let onTime = fittedWindows(fx, step)
        let late = fittedWindows(fx, step, shiftS: step.breath_ref.periodS / 2)
        let (s0, s1) = try (#require(onTime.map(\.swing).median), #require(late.map(\.swing).median))
        let (y0, y1) = try (#require(onTime.map(\.sync).median), #require(late.map(\.sync).median))
        #expect(abs(s1 - s0) / s0 < 0.1)
        #expect(abs(y1 - y0) < 0.1)
        let p0 = circularMean(onTime.map(\.peakFraction)), p1 = circularMean(late.map(\.peakFraction))
        let moved = (p0 - p1 + 1).truncatingRemainder(dividingBy: 1)   // later origin → earlier peak
        #expect(abs(moved - 0.5) < 0.05)
    }

    // MARK: helpers

    private func fittedWindows(_ fx: RSAFixture, _ step: RSAFixture.Step, shiftS: Double = 0) -> [CosinorFit] {
        let ref = step.breath_ref
        return RSAFixture.windows(fromS: step.reference.from_ms / 1000, toS: step.reference.to_ms / 1000,
                                  t0S: ref.t0_ms / 1000 + shiftS, periodS: ref.periodS)
            .compactMap { Cosinor.fit(fx.samples, periodS: ref.periodS, fromS: $0) }
    }

    private func circularMean(_ fractions: [Double]) -> Double {
        let x = fractions.map { cos(2 * .pi * $0) }.reduce(0, +)
        let y = fractions.map { sin(2 * .pi * $0) }.reduce(0, +)
        let f = atan2(y, x) / (2 * .pi)
        return f - f.rounded(.down)
    }

    private func expect(_ fit: CosinorFit, matches ref: RSAFixture.Fit, _ where_: String) {
        #expect(fit.n == ref.n, "\(where_)")
        #expect(abs(fit.swing - ref.swing_bpm) < Self.swingTolerance, "\(where_)")
        #expect(abs(fit.sync - ref.sync) < 0.001, "\(where_)")
        #expect(abs(fit.mean - ref.mean_bpm) < 0.001, "\(where_)")
        #expect(abs(fit.slope - ref.slope_bpm_per_s) < 0.001, "\(where_)")
        let dp = abs(fit.peakFraction - ref.peak_fraction)
        #expect(min(dp, 1 - dp) < 0.001, "\(where_)")
    }
}
