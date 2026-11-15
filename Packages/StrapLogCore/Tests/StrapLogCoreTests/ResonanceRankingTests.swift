import Testing
@testable import StrapLogCore

/// The resonance finder's ranking of pacer rates by swing (straplog-9fr.7).
@Suite("ResonanceRanking")
struct ResonanceRankingTests {
    /// The calibration fixture's followed steps (no holds, no settle), as `RSASummary`s.
    static func followed() throws -> [RSASummary] {
        let fx = try RSAFixture.load()
        let expected = try RSASummaryTests.Expected.load().filter { $0.label.hasPrefix("follow_") }
        let runs = expected.map {
            PacerRun(stamp: PacerStamp(breathsPerMinute: $0.rate, inhaleS: 30 / $0.rate, exhaleS: 30 / $0.rate,
                                       t0Ms: $0.t0_ms),
                     startMs: $0.start_ms, stopMs: $0.stop_ms)
        }
        return RSASummary.of(runs, tEndMs: fx.t_end_ms.map { Int64($0) }, rrMs: fx.rr_ms)
    }

    @Test("on the calibration fixture the slow rates beat 8, and 10 comes last")
    func calibration() throws {
        let ranking = try #require(ResonanceRanking(try Self.followed()))
        let rates = ranking.entries.map(\.rate)
        #expect(Set(rates) == [4.5, 6, 8, 10])
        #expect([4.5, 6].contains(ranking.best.rate))
        #expect(Array(rates.suffix(2)) == [8, 10])
        #expect(ranking.entries.map(\.swing) == ranking.entries.map(\.swing).sorted(by: >))
    }

    @Test("runs at one rate pool their windows; one rate alone ranks nothing")
    func pooling() throws {
        let followed = try Self.followed()
        let six = followed.filter { $0.run.stamp.breathsPerMinute == 6 }
        #expect(ResonanceRanking(six + six) == nil)
        let ranking = try #require(ResonanceRanking(followed + six))
        let entry = try #require(ranking.entries.first { $0.rate == 6 })
        #expect(entry.windows == 2 * six.reduce(0) { $0 + $1.block.fits.count })
        #expect(ResonanceRanking([]) == nil)
    }
}
