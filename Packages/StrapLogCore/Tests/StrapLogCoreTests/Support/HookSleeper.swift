import StrapLogCore
import Synchronization

/// A `PacerSleeper` that moves a `FakeClock` instead of waiting, never parks, and before sleep
/// `i` runs `hooks[i]` (on the main actor), e.g. to stop the recording mid-run. `lateMs(i)` makes
/// sleep `i` overshoot.
final class HookSleeper: PacerSleeper {
    private let clock: FakeClock
    private let lateMs: @Sendable (Int) -> Int64
    private let hooks: [Int: @MainActor @Sendable () async -> Void]
    private let count = Mutex(0)

    init(clock: FakeClock, lateMs: @escaping @Sendable (Int) -> Int64 = { _ in 0 },
         hooks: [Int: @MainActor @Sendable () async -> Void] = [:]) {
        self.clock = clock
        self.lateMs = lateMs
        self.hooks = hooks
    }

    var sleeps: Int { count.withLock { $0 } }

    func sleep(forMs ms: Int64) async {
        let index = count.withLock { n in defer { n += 1 }; return n }
        if let hook = hooks[index] { await hook() }
        clock.advance(byMs: ms + lateMs(index))
    }
}
