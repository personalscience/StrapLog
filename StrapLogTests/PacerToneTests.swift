import Testing
@testable import StrapLog

@Suite("PacerTone")
struct PacerToneTests {
    @Test("a tone lasts 350 ms, stays under its amplitude and starts and ends silent", arguments: [true, false])
    func tone(inhaling: Bool) throws {
        let tone = PacerTone.samples(inhaling: inhaling)
        #expect(tone.count == Int(PacerTone.duration * PacerTone.sampleRate))
        #expect(tone.allSatisfy { Double(abs($0)) <= PacerTone.amplitude })
        #expect(Double(try #require(tone.map(abs).max())) > 0.8 * PacerTone.amplitude)
        #expect(abs(tone[0]) < 0.001)
        #expect(abs(try #require(tone.last)) < 0.001)
    }

    @Test("the two tones differ")
    func distinct() {
        #expect(PacerTone.samples(inhaling: true) != PacerTone.samples(inhaling: false))
    }
}
