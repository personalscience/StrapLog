import Foundation
import Testing
@testable import HRVKit

/// RSA over a finished pacer run (straplog-9fr.6).
@Suite("RSABlock")
struct RSABlockTests {
    @Test("fixture: the block's breaths and windows are gen_rsa_fixture.py's, its median swing too",
          arguments: ["follow_6", "follow_10", "follow_4.5", "follow_8", "recover_1", "recover_2", "after_move", "armpos"])
    func fixture(label: String) throws {
        let fx = try RSAFixture.load()
        let step = fx.step(label), ref = step.reference
        let block = RSABlock(fx.samples, periodS: step.breath_ref.periodS, originS: step.breath_ref.t0_ms / 1000,
                             fromS: ref.from_ms / 1000, toS: ref.to_ms / 1000)
        #expect(block.breaths.count == ref.breaths.count)
        #expect(block.windows == ref.cosinor.windows.count)
        #expect(block.validBreaths == ref.breaths.filter { $0.swing_bpm != nil }.count)
        #expect(block.fits.count == block.windows, "every window of a followed step fits")
        let swing = try #require(block.swing), expected = try #require(ref.cosinor.median_swing_bpm)
        #expect(abs(swing - expected) < 0.01)
    }

    @Test("a sinusoid: swing, sync and peak; breaths cover the whole span")
    func sinusoid() throws {
        let samples = RSATests.beats(seconds: 95) { RSATests.sinusoid($0) }
        let block = RSABlock(samples, periodS: RSATests.period, originS: 0, fromS: 3, toS: 95)
        #expect(block.breaths.map(\.startS) == [10, 20, 30, 40, 50, 60, 70, 80])   // 80–90 the last whole one
        #expect(block.windows == 5)   // starting 10, 20, 30, 40, 50
        #expect(abs(try #require(block.swing) - 10) < 0.2)
        #expect(try #require(block.sync) > 0.95)
        #expect(abs(try #require(block.peakFraction) - 0.3) < 0.02)
        #expect(block.validBreaths == 8)
    }

    @Test("peaks either side of the breath boundary average across it, not to the middle")
    func peakCircular() throws {
        let samples = RSATests.beats(seconds: 200) { 60 + 5 * cos(2 * .pi * ($0 / RSATests.period - 0.99 - 0.0004 * $0)) }
        let block = RSABlock(samples, periodS: RSATests.period, originS: 0, fromS: 0, toS: 200)
        let peaks = block.fits.map(\.peakFraction)
        #expect(peaks.contains { $0 > 0.9 } && peaks.contains { $0 < 0.1 })
        let p = try #require(block.peakFraction)
        #expect(min(p, 1 - p) < 0.05)
    }

    @Test("shorter than a breath: no breaths, no fit")
    func tooShort() {
        let samples = RSATests.beats(seconds: 30) { _ in 60 }
        let block = RSABlock(samples, periodS: 10, originS: 0, fromS: 1, toS: 9)
        #expect(block.breaths.isEmpty && block.windows == 0)
        #expect(block.swing == nil && block.sync == nil && block.peakFraction == nil)
    }

    @Test("fewer than four breaths: breaths but no window")
    func noWindow() {
        let samples = RSATests.beats(seconds: 40) { RSATests.sinusoid($0) }
        let block = RSABlock(samples, periodS: 10, originS: 0, fromS: 0, toS: 35)
        #expect(block.breaths.count == 3 && block.windows == 0 && block.swing == nil)
    }
}
