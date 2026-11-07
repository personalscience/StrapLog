import Testing
@testable import StrapLog

@Suite("PacerTone")
struct PacerToneTests {
    func rms(_ samples: ArraySlice<Float>) -> Double {
        (samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)).squareRoot()
    }

    @Test("a tone fills its half-breath, peaks at its amplitude and starts and ends silent",
          arguments: [true, false], [5.0, 4.0, 1.5])
    func tone(inhaling: Bool, seconds: Double) throws {
        let tone = PacerTone.samples(inhaling: inhaling, seconds: seconds)
        #expect(tone.count == Int(seconds * PacerTone.sampleRate))
        let peak = Double(try #require(tone.map(abs).max()))
        #expect(peak <= PacerTone.amplitude + 1e-6)
        #expect(peak > 0.95 * PacerTone.amplitude)
        #expect(abs(tone[0]) < 0.001)
        #expect(abs(try #require(tone.last)) < 0.001)
    }

    @Test("it rings like a bell: loud at the strike, still audible mid-breath, near silent at the end")
    func decay() {
        let tone = PacerTone.samples(inhaling: true, seconds: 5)
        let tenth = tone.count / 10
        let start = rms(tone[0..<tenth])
        let middle = rms(tone[(4 * tenth)..<(6 * tenth)])
        let end = rms(tone[(9 * tenth)...])
        #expect(middle < start / 3)
        #expect(middle > start / 30, "the fade lasts the breath, not a blip")
        #expect(end < start / 30)
    }

    @Test("a short half-breath still gets the minimum tone")
    func minimum() {
        #expect(PacerTone.samples(inhaling: false, seconds: 0.1).count == PacerTone.frameCount(seconds: PacerTone.minimumSeconds))
    }

    @Test("inhale and exhale differ")
    func distinct() {
        #expect(PacerTone.samples(inhaling: true, seconds: 2) != PacerTone.samples(inhaling: false, seconds: 2))
    }
}
