import StrapLogCore
import Testing

struct StreamWatchdogTests {
    @Test func neverAttemptedIsDue() {
        #expect(StreamWatchdog().restartDue(atMs: 0))
    }

    @Test func runningStreamThatDeliversIsNotDue() {
        var dog = StreamWatchdog(retryMs: 5_000, stallMs: 10_000)
        _ = dog.attempted(atMs: 0)
        dog.received(atMs: 9_000)
        #expect(!dog.restartDue(atMs: 18_000))
        #expect(dog.restartDue(atMs: 19_000))
    }

    /// The relaunch case: a start that never delivers (or hangs) is retried after `stallMs`.
    @Test func attemptThatNeverDeliversIsDueAfterStall() {
        var dog = StreamWatchdog(retryMs: 5_000, stallMs: 10_000)
        _ = dog.attempted(atMs: 0)
        #expect(!dog.restartDue(atMs: 9_999))
        #expect(dog.restartDue(atMs: 10_000))
    }

    @Test func endedAttemptIsDueAfterRetry() {
        var dog = StreamWatchdog(retryMs: 5_000, stallMs: 10_000)
        let gen = dog.attempted(atMs: 0)
        dog.ended(generation: gen, atMs: 1_000)
        #expect(!dog.restartDue(atMs: 5_999))
        #expect(dog.restartDue(atMs: 6_000))
    }

    /// A cancelled attempt finishing late must not mark its replacement as ended.
    @Test func supersededEndIsIgnored() {
        var dog = StreamWatchdog(retryMs: 5_000, stallMs: 10_000)
        let old = dog.attempted(atMs: 0)
        _ = dog.attempted(atMs: 10_000)
        dog.ended(generation: old, atMs: 11_000)
        #expect(!dog.restartDue(atMs: 16_000))
        #expect(dog.restartDue(atMs: 20_000))
    }

    @Test func resetIsDueAtOnceAndOrphansTheRunningAttempt() {
        var dog = StreamWatchdog()
        let gen = dog.attempted(atMs: 0)
        dog.reset()
        #expect(dog.restartDue(atMs: 1))
        let next = dog.attempted(atMs: 2)
        dog.ended(generation: gen, atMs: 3)
        #expect(!dog.restartDue(atMs: 4))
        #expect(next != gen)
    }
}
