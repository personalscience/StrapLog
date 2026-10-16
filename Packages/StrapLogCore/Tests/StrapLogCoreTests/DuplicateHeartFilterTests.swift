import Testing
@testable import StrapLogCore

@Suite("DuplicateHeartFilter")
struct DuplicateHeartFilterTests {
    let t0: Int64 = 1_760_000_000_000

    func hr(_ offsetMs: Int64, bpm: Int = 72, rr: [Int] = [894]) -> SensorEvent {
        SensorEvent(atMs: t0 + offsetMs, .heartRate(bpm: bpm, contact: true, rr1024: rr))
    }

    /// Keep/drop verdicts of one fresh filter over `deliveries` (event, observer).
    func verdicts(_ deliveries: [(SensorEvent, Int?)]) -> [Bool] {
        var filter = DuplicateHeartFilter()
        return deliveries.map { filter.admit($0.0, observer: $0.1) }
    }

    /// The device trace from recording 3: every notification delivered by two observers in the same ms.
    @Test("drops the second observer's copy of each notification")
    func doubled() {
        #expect(verdicts([
            (hr(520), 1), (hr(520), 2),
            (hr(1480, rr: [896, 882]), 1), (hr(1480, rr: [896, 882]), 2),
            (hr(2928, rr: [893]), 2), (hr(2929, rr: [893]), 1),
        ]) == [true, false, true, false, true, false])
    }

    /// Recording 2 (one observer) had a genuine identical pair 1 ms apart after a BLE stall.
    @Test("keeps an identical repeat from the same observer")
    func genuineRepeat() {
        #expect(verdicts([(hr(0, bpm: 68, rr: [927]), 1), (hr(1, bpm: 68, rr: [927]), 1)]) == [true, true])
    }

    @Test("keeps back-to-back notifications whose RR differ")
    func batched() {
        #expect(verdicts([(hr(0, bpm: 76, rr: [816]), 1), (hr(0, bpm: 76, rr: [787]), 2)]) == [true, true])
    }

    @Test("keeps an identical notification outside the window")
    func steadyRhythm() {
        #expect(verdicts([(hr(0), 1), (hr(DuplicateHeartFilter.defaultWindowMs + 1), 2)]) == [true, true])
    }

    @Test("an unknown observer never counts as a different one")
    func unknownObserver() {
        #expect(verdicts([(hr(0), nil), (hr(0), 1), (hr(0), nil)]) == [true, true, true])
    }

    @Test("other payloads pass and do not reset the comparison")
    func otherPayloads() {
        #expect(verdicts([(hr(0), 1), (SensorEvent(atMs: t0, .battery(percent: 80)), 2), (hr(1), 2)])
            == [true, true, false])
    }
}
