import Foundation
import Testing
@testable import StrapLogCore

@Suite("BreathTracker")
struct BreathTrackerTests {
    let t0: Int64 = 1_760_000_000_000
    var pacer: BreathingPacer { BreathingPacer(breathsPerMinute: 6, startedAtMs: t0) }

    /// Readings after each notification.
    func track(_ notifications: [(atMs: Int64, samples: [AccSample])], pacer: BreathingPacer,
               into tracker: inout BreathTracker) -> [BreathReading] {
        notifications.compactMap { tracker.add(receivedAtMs: $0.atMs, samples: $0.samples) }
    }

    func track(_ notifications: [(atMs: Int64, samples: [AccSample])], pacer: BreathingPacer) -> [BreathReading] {
        var tracker = BreathTracker(pacer: pacer)
        return track(notifications, pacer: pacer, into: &tracker)
    }

    /// Times at which `volume` rises through the middle, with hysteresis.
    func inhaleCrossings(_ readings: [BreathReading]) -> [Int64] {
        var armed = false
        var out: [Int64] = []
        for r in readings {
            guard let v = r.volume else { armed = false; continue }
            if v < 0.35 { armed = true }
            if armed, v > 0.5 { out.append(r.atMs); armed = false }
        }
        return out
    }

    /// A breath 0.5 s behind a 6/min, 5:5 pacer.
    func lagging(_ lagMs: Int64 = 500) -> (Int64) -> Double {
        { t in (1 - cos(2 * .pi * Double(t - self.t0 - lagMs) / 10_000)) / 2 }
    }

    @Test("a recorded paced session (1 Hz gravity) gives back the pacer's 6/min")
    func fixtureRate() throws {
        let fixture = try BreathFixture.load("breathing-motion")
        let readings = track(fixture.notifications, pacer: fixture.breathingPacer)
        let crossings = inhaleCrossings(readings)
        try #require(crossings.count >= 20, "found \(crossings.count) breaths in 6 min")
        let perMinute = Double(crossings.count - 1) / Double(crossings.last! - crossings.first!) * 60_000
        #expect(abs(perMinute - 6) < 0.3, "measured \(perMinute)/min")
        let inStep = readings.compactMap(\.inStep).sorted()
        let median = inStep[inStep.count / 2]
        #expect(median > 0.3, "median in-step \(median)")
    }

    @Test("at 25 Hz the bubble tracks the breath within a second, whichever way the strap tilts",
          arguments: [1.0, -1.0])
    func tracksWithinASecond(direction: Double) throws {
        var chest = SyntheticChest(lung: lagging())
        chest.axis *= direction
        let readings = track(chest.notifications(fromMs: t0, toMs: t0 + 120_000), pacer: pacer)
        // True mid-inhale: 2.5 s into each breath, plus the 0.5 s lag.
        let crossings = inhaleCrossings(readings).filter { $0 > t0 + 40_000 }
        try #require(crossings.count >= 7)
        for c in crossings {
            let truth = t0 + 3_000 + ((c - t0 - 3_000 + 5_000) / 10_000) * 10_000
            #expect(abs(c - truth) <= 1_000, "crossed at \(c - truth) ms from the true mid-inhale")
        }
        #expect(readings.last?.inStep ?? 0 > 0.9)
    }

    @Test("no volume until calibrated against the pacer")
    func calibrates() {
        let readings = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0, toMs: t0 + 30_000), pacer: pacer)
        #expect(readings.first { $0.atMs < t0 + BreathTracker.calibrateMs }?.volume == nil)
        #expect(readings.allSatisfy { $0.atMs < t0 + BreathTracker.calibrateMs ? $0.volume == nil : true })
        #expect(readings.last?.volume != nil)
        #expect(readings.first?.caption == "Finding your breath…")
    }

    @Test("breathing half a breath off the pacer reads as out of step")
    func slipped() {
        var tracker = BreathTracker(pacer: pacer)
        _ = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0, toMs: t0 + 40_000), pacer: pacer, into: &tracker)
        let later = SyntheticChest(lung: lagging(5_500)).notifications(fromMs: t0 + 40_000, toMs: t0 + 160_000)
        let readings = track(later, pacer: pacer, into: &tracker)
        #expect(readings.last?.inStep ?? 1 < -0.8, "a half-breath slip shows, not a recalibration")
        #expect(readings.last?.caption == "In step 0%")
    }

    @Test("movement reads as not still, then the breath is found again")
    func movement() throws {
        var tracker = BreathTracker(pacer: pacer)
        _ = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0, toMs: t0 + 40_000), pacer: pacer, into: &tracker)
        var shaking = SyntheticChest(lung: lagging())
        shaking.noiseMg = 200
        let moved = track(shaking.notifications(fromMs: t0 + 40_000, toMs: t0 + 42_000), pacer: pacer, into: &tracker)
        let last = try #require(moved.last)
        #expect(!last.still && last.volume == nil)
        #expect(last.caption == "Hold still to see your breath")
        let after = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0 + 42_000, toMs: t0 + 80_000),
                          pacer: pacer, into: &tracker)
        #expect(after.first { $0.atMs >= t0 + 44_000 }?.still == true, "still again within 2 s")
        #expect(after.last?.volume != nil)
    }

    @Test("a posture change (a big slow swing) resets too")
    func postureChange() {
        var tracker = BreathTracker(pacer: pacer)
        _ = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0, toMs: t0 + 40_000), pacer: pacer, into: &tracker)
        var lying = SyntheticChest(lung: lagging())
        lying.gravity = SIMD3(950, 100, 200)
        let readings = track(lying.notifications(fromMs: t0 + 40_000, toMs: t0 + 41_000), pacer: pacer, into: &tracker)
        #expect(readings.contains { !$0.still })
    }

    @Test("a gap in the stream starts afresh")
    func gap() {
        var tracker = BreathTracker(pacer: pacer)
        _ = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0, toMs: t0 + 40_000), pacer: pacer, into: &tracker)
        let after = track(SyntheticChest(lung: lagging()).notifications(fromMs: t0 + 50_000, toMs: t0 + 52_000),
                          pacer: pacer, into: &tracker)
        #expect(after.allSatisfy { $0.volume == nil })
    }
}
