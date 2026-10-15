import Testing
@testable import StrapLogCore

@Suite("FakeHeartSource")
struct FakeHeartSourceTests {
    @Test("clock advances lazily as events are consumed")
    func lazyClock() async {
        let clock = FakeClock(startMs: 0)
        let source = FakeHeartSource(clock: clock, script: [.wait(ms: 100), hr([1]), .wait(ms: 50), hr([2]), .wait(ms: 7)])
        var it = source.events().makeAsyncIterator()
        #expect(clock.nowMs() == 0)
        #expect(await it.next()?.atMs == 100)
        #expect(clock.nowMs() == 100)
        #expect(await it.next()?.atMs == 150)
        #expect(await it.next() == nil)
        #expect(clock.nowMs() == 157)
    }
}
