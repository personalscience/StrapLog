import Foundation
import Testing
@testable import StrapLogCore

/// RSA per pacer run of a finished recording (straplog-9fr.6).
@Suite("RSASummary")
struct RSASummaryTests {
    /// `Tests/fixtures/rsa-calibration-summary.json`, written by `tools/gen_rsa_summary.py` from
    /// straplog-py's `rsa.runs`.
    struct Expected: Decodable {
        let label: String
        let start_ms: Int64
        let stop_ms: Int64
        let rate: Double
        let t0_ms: Int64
        let breaths: Int
        let breaths_valid: Int
        let windows: Int
        let windows_fitted: Int
        let swing_bpm: Double
        let sync: Double
        let peak_fraction: Double

        static func load() throws -> [Expected] {
            let url = URL(filePath: #filePath).deletingLastPathComponent()
                .appending(path: "../../../../Tests/fixtures/rsa-calibration-summary.json").standardized
            return try JSONDecoder().decode([Expected].self, from: Data(contentsOf: url))
        }
    }

    static func event(_ kind: EventKind, _ atMs: Int64, _ note: String? = nil) -> RecordingEvent {
        RecordingEvent(recordingId: 1, atMs: atMs, kind: kind, note: note)
    }

    @Test("straplog-py parity on rsa-calibration: swing within 0.1 bpm, sync within 0.01")
    func parity() throws {
        let fx = try RSAFixture.load()
        let expected = try Expected.load()
        let runs = expected.map {
            PacerRun(stamp: PacerStamp(breathsPerMinute: $0.rate, inhaleS: 30 / $0.rate, exhaleS: 30 / $0.rate,
                                       t0Ms: $0.t0_ms),
                     startMs: $0.start_ms, stopMs: $0.stop_ms)
        }
        let summaries = RSASummary.of(runs, tEndMs: fx.t_end_ms.map { Int64($0) }, rrMs: fx.rr_ms)
        #expect(summaries.count == expected.count)
        for (s, e) in zip(summaries, expected) {
            let b = s.block
            #expect(b.breaths.count == e.breaths && b.validBreaths == e.breaths_valid, "\(e.label)")
            #expect(b.windows == e.windows && b.fits.count == e.windows_fitted, "\(e.label)")
            #expect(abs(try #require(b.swing) - e.swing_bpm) < 0.1, "\(e.label)")
            #expect(abs(try #require(b.sync) - e.sync) < 0.01, "\(e.label)")
            let dp = abs(try #require(b.peakFraction) - e.peak_fraction)
            #expect(min(dp, 1 - dp) < 0.01, "\(e.label)")
        }
    }

    @Test("runs pair each start with its stop, in time order")
    func pairs() {
        let runs = PacerRun.runs([
            Self.event(.pacerStop, 9_000),
            Self.event(.pacerStart, 1_000, "6.0/min in5.0 out5.0 t0=500"),
            Self.event(.marker, 2_000),
            Self.event(.pacerStart, 10_000, "8.0/min in3.8 out3.8 t0=10000"),
            Self.event(.pacerStop, 20_000),
        ], endMs: 30_000)
        #expect(runs.map(\.startMs) == [1_000, 10_000])
        #expect(runs.map(\.stopMs) == [9_000, 20_000])
        #expect(runs.map(\.originMs) == [500, 10_000])
        #expect(runs.map(\.stamp.breathsPerMinute) == [6, 8])
    }

    @Test("an unstopped run ends at the next start, the last at the recording's end")
    func unstopped() {
        let runs = PacerRun.runs([
            Self.event(.pacerStart, 1_000, "6.0/min"),
            Self.event(.pacerStart, 5_000, "bogus"),
            Self.event(.pacerStart, 8_000, "4.5/min"),
        ], endMs: 30_000)
        #expect(runs.map(\.startMs) == [1_000, 8_000])
        #expect(runs.map(\.stopMs) == [5_000, 30_000])
        #expect(runs[0].originMs == 1_000, "a pre-1.2 note starts its breaths at the event")
    }

    @Test("a stray stop and a zero-length run are no runs")
    func degenerate() {
        #expect(PacerRun.runs([Self.event(.pacerStop, 1_000)], endMs: 9_000).isEmpty)
        #expect(PacerRun.runs([Self.event(.pacerStart, 1_000, "6.0/min"), Self.event(.pacerStop, 1_000)],
                              endMs: 9_000).isEmpty)
    }

    @Test("a run with no whole breath after settling has no summary; no beats, no summaries")
    func short() {
        let beats = (1...40).map { Int64($0) * 1_000 }
        let run = PacerRun(stamp: PacerStamp(note: "6.0/min")!, startMs: 1_000, stopMs: 15_000)
        #expect(RSASummary.of([run], tEndMs: beats, rrMs: beats.map { _ in 1_000 }).isEmpty)
        #expect(RSASummary.of([run], tEndMs: [], rrMs: []).isEmpty)
        let long = PacerRun(stamp: PacerStamp(note: "6.0/min")!, startMs: 1_000, stopMs: 40_000)
        let s = RSASummary.of([long], tEndMs: beats, rrMs: beats.map { _ in 1_000 })
        #expect(s.first?.block.breaths.count == 2, "breaths at 11–21 and 21–31 s; 31–41 runs past the stop")
    }
}
