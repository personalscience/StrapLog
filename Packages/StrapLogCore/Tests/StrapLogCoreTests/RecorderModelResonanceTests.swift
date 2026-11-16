import Foundation
import Testing
@testable import StrapLogCore

/// straplog-9fr.11: the pacer's rate and your resonance rate, kept by the model across relaunches.
@MainActor
@Suite("RecorderModel resonance")
struct RecorderModelResonanceTests {
    let database: StrapLogDatabase
    let defaults: UserDefaults

    init() throws {
        database = try .inMemory()
        defaults = try #require(UserDefaults(suiteName: "resonance-\(UUID())"))
    }

    func relaunch() throws -> RecorderModel {
        RecorderModel(database: database, exports: ExportFolder(local: try scratchDirectory()), defaults: defaults)
    }

    @Test("with nothing saved: the default rate and no resonance rate")
    func fresh() throws {
        let model = try relaunch()
        #expect(model.pacerRate == BreathingPacer.defaultRate)
        #expect(model.resonance == nil)
    }

    @Test("the pacer's rate is snapped and survives a relaunch")
    func pacerRate() throws {
        try relaunch().setPacerRate(5.4)
        #expect(try relaunch().pacerRate == 5.5)
        defaults.set(12.0, forKey: PacerSettings.rateKey)
        #expect(try relaunch().pacerRate == BreathingPacer.rates.upperBound)
    }

    @Test("recording a result keeps the pacer's rate; using one sets both; both survive a relaunch")
    func result() throws {
        let found = ResonanceResult(rate: 5, foundAtMs: 1_763_200_000_000, tzOffsetS: -28_800)
        let model = try relaunch()
        model.recordResonance(found)
        #expect(model.resonance == found)
        #expect(model.pacerRate == BreathingPacer.defaultRate)
        let used = ResonanceResult(rate: 6.5, foundAtMs: 1_763_300_000_000, tzOffsetS: -28_800)
        model.useResonance(used)
        let again = try relaunch()
        #expect(again.resonance == used)
        #expect(again.pacerRate == 6.5)
        defaults.set(Data("junk".utf8), forKey: PacerSettings.resonanceKey)
        #expect(try relaunch().resonance == nil, "unreadable reads as none")
    }
}
