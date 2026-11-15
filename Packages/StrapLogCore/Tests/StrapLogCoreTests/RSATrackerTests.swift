import Foundation
import HRVKit
import Testing
@testable import StrapLogCore

/// What one pacer's tracker produced, beat by beat.
private struct Replay {
    var readings: [RSAReading] = []
    /// Each breath once, as it closed, with the fit made at that moment.
    var closed: [(breath: BreathSwing, fit: CosinorFit?)] = []

    init(_ pacer: BreathingPacer, _ beats: [(tEndMs: Int64, rrMs: Double)]) {
        var tracker = RSATracker(pacer: pacer)
        for beat in beats {
            guard let r = tracker.add(tEndMs: beat.tEndMs, rrMs: beat.rrMs) else { continue }
            if let last = r.breaths.last, last.startS != closed.last?.breath.startS {
                closed.append((last, r.fit))
            }
            readings.append(r)
        }
    }

    var fits: [CosinorFit] { closed.compactMap(\.fit) }
}

/// Beats whose instant HR is `hr(t)` (t in s from `fromMs`) at each beat's mid-interval,
/// one after another from `fromMs`.
private func beats(fromMs: Int64, seconds: Double, hr: (Double) -> Double) -> [(tEndMs: Int64, rrMs: Double)] {
    var out: [(Int64, Double)] = []
    var t = 0.0
    while t < seconds {
        let rr = 60_000 / hr(t + 30 / hr(t))
        t += rr / 1000
        out.append((fromMs + Int64((t * 1000).rounded()), rr))
    }
    return out
}

private func median(_ xs: [Double]) -> Double? {
    guard !xs.isEmpty else { return nil }
    let s = xs.sorted(), m = s.count / 2
    return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
}

@Suite("RSATracker")
struct RSATrackerTests {
    static let t0: Int64 = 1_762_070_400_000
    let pacer = BreathingPacer(breathsPerMinute: 6, startedAtMs: RSATrackerTests.t0)

    /// HR 60 ± 5 bpm at 6/min, peaking 0.6 of the way through each breath.
    func sinus(_ t: Double) -> Double { 60 + 5 * cos(2 * .pi * (t / 10 - 0.6)) }

    @Test("a clean sinusoid: one swing per breath, fit after 4 breaths with its swing, sync and peak")
    func sinusoid() throws {
        let replay = Replay(pacer, beats(fromMs: Self.t0, seconds: 120, hr: sinus))
        let starts = replay.closed.map(\.breath.startS)
        #expect(starts == (0..<starts.count).map { Double($0) * 10 }, "one breath each, in order, none skipped")
        #expect(starts.count >= 11)
        #expect(replay.closed.prefix(3).allSatisfy { $0.fit == nil })
        let fit = try #require(replay.readings.last?.fit)
        #expect(abs(fit.swing - 10) < 0.3)
        #expect(fit.sync > 0.95)
        #expect(abs(fit.peakFraction - 0.6) < 0.03)
        for (b, _) in replay.closed { #expect(abs(try #require(b.swing) - 10) < 0.6) }
    }

    @Test("warming up until 2 breaths close; the trace holds the last minute; at most 12 breaths")
    func warmUpAndLimits() throws {
        let replay = Replay(pacer, beats(fromMs: Self.t0, seconds: 200, hr: sinus))
        let firstWarm = try #require(replay.readings.firstIndex { !$0.warmingUp })
        #expect(replay.readings[firstWarm].breaths.count == RSATracker.warmUpBreaths)
        #expect(replay.readings[firstWarm].atMs >= pacer.breathStartMs(2))
        #expect(replay.readings[..<firstWarm].allSatisfy { $0.warmingUp && $0.fit == nil })
        let last = try #require(replay.readings.last)
        #expect(last.breaths.count == RSATracker.keptBreaths)
        let span = try #require(last.trace.last).atMs - (try #require(last.trace.first)).atMs
        #expect(span <= Int64(RSADefaults.traceSeconds * 1000) && span > 55_000)
        #expect(last.trace.allSatisfy { abs($0.value - 60) <= 5.01 })
    }

    @Test("a tracker started mid-breath waits for the next whole breath")
    func lateStart() throws {
        let replay = Replay(pacer, beats(fromMs: Self.t0 + 4_000, seconds: 60, hr: sinus))
        #expect(replay.closed.first?.breath.startS == 10)
    }

    @Test("a beat gap over 5 s starts afresh")
    func gap() throws {
        let before = beats(fromMs: Self.t0, seconds: 60, hr: sinus)
        let resume = before.last!.tEndMs + RSATracker.gapMs + 1
        var tracker = RSATracker(pacer: pacer)
        var last: RSAReading?
        for b in before { last = tracker.add(tEndMs: b.tEndMs, rrMs: b.rrMs) }
        #expect(last?.fit != nil)
        last = tracker.add(tEndMs: resume, rrMs: 1000)
        let r = try #require(last)
        #expect(r.warmingUp && r.fit == nil && r.breaths.isEmpty)
        #expect(r.trace.count == 1)
    }

    @Test("an ectopic beat is cleaned out of the trace")
    func ectopic() throws {
        var bs = beats(fromMs: Self.t0, seconds: 60, hr: { _ in 60 })
        bs[30].rrMs = 600   // premature beat
        let r = try #require(Replay(pacer, bs).readings.last)
        #expect(r.trace.allSatisfy { abs($0.value - 60) < 1 })
    }

    // MARK: 261115 calibration fixture, a fresh tracker per pacer start (as live)

    /// Each followed step replayed from its pacer start, as the app would.
    private func followed(_ fx: RSAFixture, _ label: String) -> Replay {
        let step = fx.step(label)
        return Replay(step.pacer, fx.beats(fromMs: max(Int64(step.from_ms), step.pacer.startedAtMs),
                                           toMs: Int64(step.to_ms)))
    }

    @Test("fixture: per-breath swings match gen_rsa_fixture.py, and readings appear after 2 breaths",
          arguments: ["follow_6", "follow_10", "follow_4.5", "follow_8", "recover_1", "recover_2", "after_move", "armpos"])
    func fixtureBreaths(label: String) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label)
        let replay = followed(fx, label)
        let starts = replay.closed.map { step.pacer.startedAtMs + Int64(($0.breath.startS * 1000).rounded()) }
        #expect(starts == starts.indices.map { step.pacer.breathStartMs($0) }, "one per breath from the pacer start")
        let firstWarm = try #require(replay.readings.firstIndex { !$0.warmingUp })
        #expect(replay.readings[firstWarm].atMs >= step.pacer.breathStartMs(2))
        #expect(replay.readings[firstWarm].atMs < step.pacer.breathStartMs(3))
        var compared = 0
        for ref in step.reference.breaths {
            guard let live = zip(starts, replay.closed).first(where: { abs(Double($0.0) - ref.from_ms) <= 1 })?.1.breath
            else { continue }
            switch (live.swing, ref.swing_bpm) {
            case (nil, nil): break
            case let (s?, r?): #expect(abs(s - r) < 0.1, "\(label) @\(ref.from_ms)")
            default: Issue.record("\(label) @\(ref.from_ms): live \(String(describing: live.swing)) vs \(String(describing: ref.swing_bpm))")
            }
            compared += 1
        }
        #expect(compared >= step.reference.breaths.count - 1)
    }

    @Test("fixture: median fitted swing ranks 4.5 and 6 above 8 above 10 /min")
    func fixtureRanking() throws {
        let fx = try RSAFixture.load()
        func m(_ label: String) throws -> Double { try #require(median(followed(fx, label).fits.map(\.swing))) }
        let (r45, r6, r8, r10) = try (m("follow_4.5"), m("follow_6"), m("follow_8"), m("follow_10"))
        #expect(min(r45, r6) > r8)
        #expect(r8 > r10)
        #expect(r45 > 10 && r6 > 7)
    }

    /// The pacer runs on through a hold (virtual pacer); the first fit whose window lies in
    /// the hold. It reaches past the 30 s hold into the recovery, as in HRVKit's test.
    @Test("fixture: a breath hold reads sync < 0.2 and under half the followed swing", arguments: ["hold_1", "hold_2"])
    func fixtureHolds(label: String) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label)
        let replay = Replay(step.pacer, fx.beats(fromMs: Int64(step.from_ms), toMs: Int64(step.to_ms) + 30_000))
        let fit = try #require(replay.fits.first)
        let followed6 = try #require(median(followed(fx, "follow_6").fits.map(\.swing)))
        #expect(fit.sync < 0.2)
        #expect(fit.swing < followed6 / 2)
    }
}

@Suite("RSATraceScale")
struct RSATraceScaleTests {
    func trace(_ values: [Double]) -> [TrendPoint] { values.enumerated().map { TrendPoint(atMs: Int64($0.offset), value: $0.element) } }

    @Test("padded, whole bpm, at least 10 bpm tall; none for an empty trace")
    func scale() throws {
        #expect(RSATraceScale([]) == nil)
        let wide = try #require(RSATraceScale(trace([50, 80])))
        #expect(wide.lowBpm == 47 && wide.highBpm == 83)
        let flat = try #require(RSATraceScale(trace([60, 61.5])))
        #expect(flat.highBpm - flat.lowBpm >= RSATraceScale.minSpanBpm)
        #expect(flat.lowBpm <= 60 && flat.highBpm >= 61.5)
        #expect(wide.fraction(47) == 0 && wide.fraction(83) == 1)
    }
}
