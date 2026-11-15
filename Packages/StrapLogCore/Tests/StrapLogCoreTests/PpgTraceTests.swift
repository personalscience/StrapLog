import Testing
@testable import StrapLogCore

@Suite("PpgTrace")
struct PpgTraceTests {
    /// `seconds` of a 1 Hz triangle pulse between `base` and `base + amplitude`, 32 samples a second.
    func pulses(seconds: Int, base: Int = 7000, amplitude: Int = 320) -> [PpgSample] {
        (0..<(seconds * 32)).map { i in
            let phase = i % 32
            let up = phase < 16 ? phase : 32 - phase
            return PpgSample(receivedAtMs: Int64(i) * 31, counter: i % 256, value: base + up * amplitude / 16)
        }
    }

    @Test("amplitude is the median one-second peak-to-trough, once five seconds have arrived")
    func amplitude() {
        var t = PpgTrace()
        t.add(Array(pulses(seconds: 4)))
        #expect(t.pulseAmplitude == nil)
        t.add(Array(pulses(seconds: 1)))
        #expect(t.pulseAmplitude == 320)
    }

    @Test("one window spoiled by movement does not move the median")
    func robust() {
        var t = PpgTrace()
        var s = pulses(seconds: 5)
        s[40].value += 5000
        t.add(s)
        #expect(t.pulseAmplitude == 320)
    }

    @Test("off the skin: no amplitude, no waveform; ten seconds are kept")
    func offSkinAndKeep() {
        var t = PpgTrace()
        t.add(pulses(seconds: 12))
        #expect(t.values.count == PpgTrace.keepSamples)
        t.add([PpgSample(receivedAtMs: 0, counter: 0, value: PpgTrace.offSkinValue)])
        #expect(t.offSkin && t.values.isEmpty && t.pulseAmplitude == nil)
    }
}
