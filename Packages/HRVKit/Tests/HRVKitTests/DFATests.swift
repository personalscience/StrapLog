import Testing
@testable import HRVKit

@Suite("DFA α1")
struct DFATests {
    /// Theory says 0.5, but at scales 4–16 this estimator (and analyze_h10's) reads
    /// white noise high: numpy over 30 seeds gives 0.587 ± 0.013. Test the estimator.
    @Test("white noise gives α1 ≈ 0.59 (0.5 plus small-scale bias)", arguments: [1, 2, 3] as [UInt64])
    func whiteNoise(seed: UInt64) throws {
        var g = SeededGaussian(seed: seed)
        let rr = g.series(4000).map { 800 + 30 * $0 }
        let a = try #require(DFA.alpha1(rr))
        #expect(abs(a - 0.59) < 0.05)
    }

    @Test("random walk gives α1 ≈ 1.5", arguments: [1, 2, 3] as [UInt64])
    func randomWalk(seed: UInt64) throws {
        var g = SeededGaussian(seed: seed)
        var level = 800.0
        let rr = g.series(4000).map { level += $0; return level }
        let a = try #require(DFA.alpha1(rr))
        #expect(abs(a - 1.5) < 0.1)
    }

    @Test("needs at least 4 × the largest scale")
    func minimumLength() {
        var g = SeededGaussian(seed: 9)
        let rr = g.series(64).map { 800 + 30 * $0 }
        #expect(DFA.alpha1(Array(rr.prefix(63))) == nil)
        #expect(DFA.alpha1(rr) != nil)
    }

    @Test("constant series has no fluctuation, so no α1")
    func constant() {
        #expect(DFA.alpha1([Double](repeating: 800, count: 200)) == nil)
    }

    @Test("empty input")
    func empty() {
        #expect(DFA.alpha1([]) == nil)
    }

    @Test("detrending removes a pure line within each box")
    func linearBoxes() {
        let y = (0..<64).map(Double.init)
        #expect(DFA.fluctuation(y, boxSize: 16)! < 1e-9)
        #expect(DFA.fluctuation(y, boxSize: 17) == nil)   // only 3 boxes
    }
}
