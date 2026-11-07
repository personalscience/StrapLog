import Foundation
import Testing
@testable import StrapLogCore

@Suite("ECG: R peaks, trace and beat pulse")
struct EcgTests {
    static let rr: [Double] = (0..<20).map { 1000 + 120 * sin(Double($0) * 0.7) }
    let sampleMs = 1000 / SyntheticECG.hz

    func detect(_ ecg: SyntheticECG) -> [Double] {
        var detector = RPeakDetector()
        return ecg.samples.compactMap { detector.add(atMs: Double($0.deviceNs) / 1e6, value: Double($0.microvolts)) }
    }

    @Test("every R peak after the warm-up is found within a sample, and T waves are not", arguments: [1.0, -1.0])
    func peaks(polarity: Double) {
        let ecg = SyntheticECG(rrMs: Self.rr, polarity: polarity)
        let found = detect(ecg).map { $0 - 7_000_000 }
        let expected = ecg.beatsMs.filter { $0 > RPeakDetector.warmUpMs + 100 }
        #expect(found.count == expected.count)
        for (f, e) in zip(found, expected) { #expect(abs(f - e) <= sampleMs, "\(f) vs \(e)") }
    }

    @Test("a gap in the samples starts the detector over instead of joining across it")
    func gap() {
        let ecg = SyntheticECG(rrMs: Self.rr)
        var detector = RPeakDetector()
        var found: [Double] = []
        for (i, s) in ecg.samples.enumerated() {
            let shift = i >= ecg.samples.count / 2 ? 5_000.0 : 0
            if let beat = detector.add(atMs: Double(s.deviceNs) / 1e6 + shift, value: Double(s.microvolts)) { found.append(beat) }
        }
        let gapAt = Double(ecg.samples[ecg.samples.count / 2].deviceNs) / 1e6
        #expect(!found.contains { $0 > gapAt && $0 < gapAt + 5_000 + RPeakDetector.warmUpMs })
        #expect(found.contains { $0 > gapAt + 5_000 + RPeakDetector.warmUpMs })
    }

    @Test("the trace maps strap time to phone time by the least-delayed batch and finds the beats")
    func trace() throws {
        let ecg = SyntheticECG(rrMs: Self.rr)
        let phoneStart = 1_760_000_000_000.0
        var trace = EcgTrace()
        // 73-sample batches, as the H10 sends them, each received 40 ms late except one 15 ms late.
        for (n, start) in stride(from: 0, to: ecg.samples.count, by: 73).enumerated() {
            let batch = Array(ecg.samples[start..<min(start + 73, ecg.samples.count)])
            let lastMs = Double(batch.last!.deviceNs) / 1e6 - 7_000_000
            trace.add(batch, receivedAtMs: Int64(phoneStart + lastMs + (n == 5 ? 15 : 40)))
        }
        let points = trace.points(fromMs: 0)
        #expect(Double(points.count) <= EcgTrace.keepMs / sampleMs + 2)
        let last = try #require(points.last)
        #expect(abs(last.atMs - (phoneStart + Double(ecg.samples.last!.deviceNs) / 1e6 - 7_000_000 + 15)) < 1, "receipt times are whole ms")
        let offset = last.atMs - (phoneStart + Double(ecg.samples.last!.deviceNs) / 1e6 - 7_000_000)
        let beats = trace.beatsMs.map { $0 - phoneStart - offset }
        let expected = ecg.beatsMs.filter { $0 >= beats.first! - 1 }
        #expect(beats.count == expected.count)
        for (b, e) in zip(beats, expected) { #expect(abs(b - e) <= sampleMs) }
        let pulse = try #require(trace.pulse)
        #expect(abs(pulse.rrMs - (expected[expected.count - 1] - expected[expected.count - 2])) <= 2 * sampleMs)
    }

    @Test("a strap clock that jumps starts the trace over")
    func clockJump() {
        let ecg = SyntheticECG(rrMs: Self.rr)
        var trace = EcgTrace()
        trace.add(Array(ecg.samples[0..<73]), receivedAtMs: 1_000_000)
        let later = ecg.samples[73..<146].map { EcgSample(deviceNs: $0.deviceNs + 3_600_000_000_000, microvolts: $0.microvolts) }
        trace.add(later, receivedAtMs: 1_000_600)
        #expect(trace.points(fromMs: 0).count == 73)
    }

    @Test("the pulse is 1 on each beat carried forward, fades between, and stops when stale")
    func pulse() {
        let pulse = BeatPulse(lastBeatMs: 10_000, rrMs: 800)
        #expect(pulse.intensity(atMs: 9_999) == 0)
        #expect(pulse.intensity(atMs: 10_000) == 1)
        #expect(abs(pulse.intensity(atMs: 10_150) - exp(-1)) < 1e-9)
        #expect(pulse.intensity(atMs: 10_700) < 0.01)
        #expect(pulse.intensity(atMs: 11_600) == 1, "two beats on")
        #expect(pulse.intensity(atMs: 10_000 + BeatPulse.staleAfterMs) == 0)
    }
}
