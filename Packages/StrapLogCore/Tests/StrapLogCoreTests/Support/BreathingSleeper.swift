import Foundation
@testable import StrapLogCore

/// A `PacerSleeper` that fills each sleep with heartbeats following the model's pacer: HR swings
/// sinusoidally with the breath, by `swing(rate)` bpm peak to peak, around 60 bpm (steady with
/// no pacer). Lets a `TrainingRunner` test end with a recording whose rates really rank.
final class BreathingSleeper: PacerSleeper {
    private let clock: FakeClock
    private let model: RecorderModel
    private let swing: @Sendable (Double) -> Double

    init(clock: FakeClock, model: RecorderModel, swing: @escaping @Sendable (Double) -> Double) {
        self.clock = clock
        self.model = model
        self.swing = swing
    }

    func sleep(forMs ms: Int64) async {
        await breathe(forMs: ms)
    }

    @MainActor private func breathe(forMs ms: Int64) async {
        let endMs = clock.nowMs() + ms
        var atMs = clock.nowMs()
        var steps: [FakeHeartSource.Step] = []
        while true {
            let rr1024 = Int((60_000 / bpm(atMs: atMs) * 1.024).rounded())
            let rrMs = Int64(BeatTiming.ms(fromRR1024: rr1024).rounded())
            if atMs + rrMs > endMs { break }
            steps += [.wait(ms: rrMs), .emit(.heartRate(bpm: 60, contact: true, rr1024: [rr1024]))]
            atMs += rrMs
        }
        await model.consume(FakeHeartSource(clock: clock, script: steps))
        clock.advance(byMs: endMs - clock.nowMs())
    }

    @MainActor private func bpm(atMs: Int64) -> Double {
        guard let pacer = model.pacer else { return 60 }
        let phase = Double(atMs - pacer.startedAtMs) / pacer.periodMs
        return 60 + swing(pacer.breathsPerMinute) / 2 * sin(2 * .pi * phase)
    }
}
