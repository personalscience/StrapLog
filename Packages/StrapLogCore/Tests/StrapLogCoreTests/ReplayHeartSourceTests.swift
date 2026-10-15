import Foundation
import Synchronization
import Testing
@testable import StrapLogCore

@Suite("ReplayHeartSource")
struct ReplayHeartSourceTests {
    @Test("beats are grouped by the whole second in which they end")
    func grouping() {
        let source = ReplayHeartSource(rrMs: [400, 400, 400, 1000, 2500, 500])
        // ends: 0.4 0.8 1.2 2.2 4.7 5.2
        #expect(source.notifications == [[410, 410], [410], [1024], [], [2560], [512]])
    }

    @Test("ms → 1/1024 s rounds to nearest")
    func conversion() {
        #expect(ReplayHeartSource(rrMs: [781.25, 999]).notifications.flatMap { $0 } == [800, 1023])
    }

    @Test("emits connect, battery, then one HR per tick, sleeping 1/speed s each")
    func timingWithFakeClock() async {
        let clock = FakeClock()
        let slept = Mutex<[Duration]>([])
        let source = ReplayHeartSource(rrMs: [1000, 1000, 1000], speed: 50, clock: clock) { d in
            slept.withLock { $0.append(d) }
            clock.advance(byMs: Int64(d / .milliseconds(1)))
        }
        let t0 = clock.nowMs()
        var events: [SensorEvent] = []
        for await e in source.events() { events.append(e) }

        #expect(slept.withLock { $0 } == Array(repeating: .milliseconds(20), count: 3))
        #expect(events.first?.payload == .connected(deviceId: ReplayHeartSource.deviceId, firmware: "replay"))
        #expect(events[1].payload == .battery(percent: 100))
        #expect(events.dropFirst(2).map(\.payload) == Array(repeating: .heartRate(bpm: 60, contact: true, rr1024: [1024]), count: 3))
        #expect(events.dropFirst(2).map { $0.atMs - t0 } == [20, 40, 60])
    }

    @Test("real-time replay at 50× takes about 1/50 of the recording")
    func timingWallClock() async {
        let source = ReplayHeartSource(rrMs: Array(repeating: 1000, count: 10), speed: 50)
        let start = ContinuousClock.now
        var n = 0
        for await _ in source.events() { n += 1 }
        let elapsed = ContinuousClock.now - start
        #expect(n == 12)
        #expect(elapsed >= .milliseconds(180) && elapsed < .milliseconds(1500))
    }

    @Test("loads a fixture's rr_ms")
    func fixture() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../Tests/fixtures/resting.json").standardized
        let source = try ReplayHeartSource.fixture(at: url)
        #expect(source.rrMs.count == 961)
        #expect(source.notifications.flatMap { $0 }.count == 961)
    }
}
