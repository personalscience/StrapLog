import ChileafKit
import Testing

@Suite("HR-silence watchdog")
struct HeartRateWatchdogTests {
    @Test("Steady notifications never trigger")
    func steady() {
        var dog = HeartRateWatchdog()
        dog.started(atMs: 0)
        for t in stride(from: Int64(1_000), through: 60_000, by: 1_000) {
            dog.received(atMs: t)
            #expect(dog.check(atMs: t + 500) == .none)
        }
    }

    @Test("Silence resubscribes, then reconnects")
    func escalates() {
        var dog = HeartRateWatchdog()
        dog.started(atMs: 0)
        dog.received(atMs: 1_000)
        #expect(dog.check(atMs: 10_999) == .none)
        #expect(dog.check(atMs: 11_000) == .resubscribe)
        #expect(dog.check(atMs: 15_000) == .none)
        #expect(dog.check(atMs: 21_000) == .reconnect)
    }

    @Test("HR after a resubscribe returns to normal")
    func recovers() {
        var dog = HeartRateWatchdog()
        dog.started(atMs: 0)
        #expect(dog.check(atMs: 10_000) == .resubscribe)
        dog.received(atMs: 12_000)
        #expect(dog.check(atMs: 21_000) == .none)
        #expect(dog.check(atMs: 22_000) == .resubscribe, "a fresh stall starts over at resubscribe")
    }

    @Test("Idle until started; reset disarms")
    func armed() {
        var dog = HeartRateWatchdog()
        #expect(dog.check(atMs: 100_000) == .none)
        dog.started(atMs: 0)
        dog.reset()
        #expect(dog.check(atMs: 100_000) == .none)
    }
}
