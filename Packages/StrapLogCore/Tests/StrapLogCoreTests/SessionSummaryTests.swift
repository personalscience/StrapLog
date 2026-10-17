import Foundation
import Testing
@testable import StrapLogCore

@Suite("SessionSummary")
struct SessionSummaryTests {
    /// The fixtures' `clean` block and windows: the skill's own numbers (`tools/gen_fixtures.py`).
    struct Reference: Decodable {
        struct Clean: Decodable {
            let removed_indices: [Int]
            let mean_hr_bpm: Double
            let rmssd_ms: Double
        }
        struct Window: Decodable { let alpha1: Double?; let hr_bpm: Double }
        let clean: Clean
        let windows: [Window]
    }

    @Test("whole-series numbers match the skill; α1 minutes are one per 60 s-stride window", arguments: RRFixture.names)
    func fixtureParity(name: String) throws {
        let fixture = try RRFixture.load(name)
        let reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf: RRFixture.url(name)))
        let summary = SessionSummary(rrMs: fixture.rr_ms, tEndMs: fixture.endTimesMs(), durationMs: nil, coverage: 1)

        #expect(summary.beats == fixture.rr_ms.count)
        #expect(summary.artifactRate == Double(reference.clean.removed_indices.count) / Double(fixture.rr_ms.count))
        #expect(abs(try #require(summary.meanHR) - reference.clean.mean_hr_bpm) < 0.01)
        #expect(abs(try #require(summary.rmssd) - reference.clean.rmssd_ms) < 0.1)

        let lowest = try #require(reference.windows.map(\.hr_bpm).min())
        #expect(abs(try #require(summary.lowestHR) - lowest) < 0.01)

        let alphas = reference.windows.compactMap(\.alpha1)
        #expect(summary.alpha1Minutes.values.reduce(0, +) == Double(alphas.count))
        // α1 parity is ±0.02, so a window near a band edge may land in the neighbouring band.
        for band in Alpha1Band.allCases {
            let expected = alphas.filter { Alpha1Band(alpha1: $0) == band }.count
            #expect(abs((summary.alpha1Minutes[band] ?? 0) - Double(expected)) <= 2, "\(band)")
        }
    }

    @Test("no beats: counts are zero and every metric is nil")
    func empty() {
        let summary = SessionSummary(rrMs: [], tEndMs: [], durationMs: 5000, coverage: 0)
        #expect(summary == SessionSummary(rrMs: [], tEndMs: [], durationMs: 5000, coverage: 0))
        #expect(summary.beats == 0)
        #expect(summary.meanHR == nil && summary.lowestHR == nil && summary.rmssd == nil && summary.artifactRate == nil)
        #expect(summary.alpha1Minutes.isEmpty)
    }
}
