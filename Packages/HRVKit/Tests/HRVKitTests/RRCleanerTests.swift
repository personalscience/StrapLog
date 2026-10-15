import Testing
@testable import HRVKit

@Suite("RRCleaner")
struct RRCleanerTests {
    let cleaner = RRCleaner()

    @Test("clean series passes through untouched")
    func cleanSeries() {
        let rr: [Double] = [800, 810, 790, 805, 795, 800, 812]
        let result = cleaner.clean(rr)
        #expect(result.removedIndices.isEmpty)
        #expect(result.kept == rr)
        #expect(result.artifactRate == 0)
    }

    @Test("gate is inclusive at 300 and 2000 ms")
    func gateBounds() {
        let gate = RRCleaner(pctThresh: .infinity)
        #expect(gate.clean([299.9, 300, 2000, 2000.1]).removedIndices == [0, 3])
    }

    @Test("missed beat (doubled RR) is removed")
    func missedBeat() {
        let rr: [Double] = [800, 805, 795, 1600, 800, 810, 790]
        #expect(cleaner.clean(rr).removedIndices == [3])
    }

    @Test("extra beat (split RR) removes both halves")
    func extraBeat() {
        let rr: [Double] = [800, 805, 795, 400, 400, 800, 810, 790]
        #expect(cleaner.clean(rr).removedIndices == [3, 4])
    }

    @Test("non-finite input is removed, never propagated")
    func nonFinite() {
        let rr: [Double] = [800, .nan, 805, .infinity, 795, 800, -.infinity]
        let result = cleaner.clean(rr)
        #expect(result.removedIndices == [1, 3, 6])
        #expect(result.kept.allSatisfy { $0.isFinite })
    }

    @Test("empty input")
    func empty() {
        let result = cleaner.clean([])
        #expect(result.kept.isEmpty)
        #expect(result.artifactRate == nil)
    }

    @Test("too few neighbours for a median leaves beats alone")
    func shortInput() {
        // With 2 beats no window has 3 present values, so nothing beyond the gate is judged.
        #expect(cleaner.clean([800, 1600]).removedIndices.isEmpty)
    }

    @Test("centered median matches pandas edge and even-count behaviour")
    func centeredMedians() {
        let m = RRCleaner.centeredMedians([1, 2, nil, 4, 5])
        // i=0: {1,2} -> nil; i=1: {1,2,4} -> 2; i=2: {1,2,4,5} -> 3; i=3: {2,4,5} -> 4; i=4: {4,5} -> nil
        #expect(m == [nil, 2, 3, 4, nil])
    }

    @Test("artifact rate counts gate and filter removals")
    func artifactRate() {
        let rr: [Double] = [800, 805, 250, 795, 1600, 800, 810, 790]
        let result = cleaner.clean(rr)
        #expect(result.artifactCount == 2)
        #expect(result.artifactRate == 0.25)
    }
}
