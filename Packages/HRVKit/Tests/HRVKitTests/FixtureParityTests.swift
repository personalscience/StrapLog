import Testing
@testable import HRVKit

/// HRVKit against analyze_h10.py on real HRV Logger recordings
/// (`tools/gen_fixtures.py`). Tolerances from the P1 acceptance criteria.
@Suite("Fixture parity vs analyze_h10.py")
struct FixtureParityTests {
    static let msTolerance = 0.1
    static let alphaTolerance = 0.02

    @Test("fixture constants match HRVDefaults", arguments: Fixture.names)
    func constants(name: String) throws {
        let c = try Fixture.load(name).constants
        #expect(c.window_s == HRVDefaults.windowSeconds)
        #expect(c.stride_s == HRVDefaults.strideSeconds)
        #expect(c.pct_thresh == HRVDefaults.pctThresh)
        #expect(c.min_beats_per_window == HRVDefaults.minBeatsPerWindow)
        #expect(c.dfa_scale_min...c.dfa_scale_max == HRVDefaults.dfaScales)
    }

    @Test("whole-recording cleaning removes exactly the same beats", arguments: Fixture.names)
    func cleaning(name: String) throws {
        let fx = try Fixture.load(name)
        let result = RRCleaner().clean(fx.rr_ms)
        #expect(result.removedIndices == fx.clean.removed_indices)
        #expect(result.kept.count == fx.clean.n_clean)
    }

    @Test("whole-recording metrics", arguments: Fixture.names)
    func wholeRecording(name: String) throws {
        let fx = try Fixture.load(name)
        let clean = RRCleaner().clean(fx.rr_ms).kept
        #expect(try abs(#require(TimeDomain.rmssd(clean)) - fx.clean.rmssd_ms) < Self.msTolerance)
        #expect(try abs(#require(TimeDomain.sdnn(clean)) - fx.clean.sdnn_ms) < Self.msTolerance)
        #expect(try abs(#require(TimeDomain.meanHR(clean)) - fx.clean.mean_hr_bpm) < 1e-6)
        try expectAlpha(DFA.alpha1(clean), fx.clean.alpha1)
    }

    @Test("windowed features match rolling_features row for row", arguments: Fixture.names)
    func windows(name: String) throws {
        let fx = try Fixture.load(name)
        let got = WindowAnalyzer().features(fx.beats)
        try #require(got.count == fx.windows.count)
        for (g, e) in zip(got, fx.windows) {
            #expect(g.tCenter == e.t_center_s)
            #expect(g.nRaw == e.n_raw)
            #expect(g.nBeats == e.n_beats, "artifact count differs at t=\(e.t_center_s)")
            #expect(abs(g.hrBpm - e.hr_bpm) < 1e-6)
            #expect(try abs(#require(g.rmssd) - #require(e.rmssd_ms)) < Self.msTolerance)
            #expect(try abs(#require(g.sdnn) - e.sdnn_ms) < Self.msTolerance)
            try expectAlpha(g.alpha1, e.alpha1)
        }
    }

    private func expectAlpha(_ got: Double?, _ expected: Double?) throws {
        guard let expected else {
            #expect(got == nil)
            return
        }
        #expect(try abs(#require(got) - expected) < Self.alphaTolerance)
    }
}
