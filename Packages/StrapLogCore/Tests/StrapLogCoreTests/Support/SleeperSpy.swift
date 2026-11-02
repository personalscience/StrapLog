import StrapLogCore
import Synchronization

/// A `PacerSleeper` that moves a `FakeClock` instead of waiting. After `limit` sleeps it parks
/// until cancelled, and `parked` tells the test the clock has done all it will. `lateMs[i]` makes
/// sleep `i` overshoot.
final class SleeperSpy: PacerSleeper {
    let parked: AsyncStream<Void>
    private let parkedContinuation: AsyncStream<Void>.Continuation
    private let clock: FakeClock
    private let limit: Int
    private let lateMs: [Int: Int64]
    private let requested = Mutex<[Int64]>([])

    init(clock: FakeClock, limit: Int, lateMs: [Int: Int64] = [:]) {
        (parked, parkedContinuation) = AsyncStream.makeStream()
        self.clock = clock
        self.limit = limit
        self.lateMs = lateMs
    }

    var sleeps: [Int64] { requested.withLock { $0 } }

    func sleep(forMs ms: Int64) async {
        let index = requested.withLock { $0.append(ms); return $0.count - 1 }
        guard index < limit else {
            parkedContinuation.yield()
            try? await Task.sleep(for: .seconds(3600))
            return
        }
        clock.advance(byMs: ms + (lateMs[index] ?? 0))
    }

    /// Waits until the clock has used up its sleeps.
    func waitUntilParked() async {
        for await _ in parked { return }
    }
}
