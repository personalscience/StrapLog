import Synchronization

/// A clock that moves only when told to. Shared by tests and `FakeHeartSource`.
public final class FakeClock: WallClock {
    private let ms: Mutex<Int64>
    private let tzOffsetS: Int

    public init(startMs: Int64 = 1_760_000_000_000, tzOffsetS: Int = -7 * 3600) {
        self.ms = Mutex(startMs)
        self.tzOffsetS = tzOffsetS
    }

    public func nowMs() -> Int64 { ms.withLock { $0 } }

    public func tzOffsetSeconds(atMs ms: Int64) -> Int { tzOffsetS }

    public func advance(byMs delta: Int64) {
        ms.withLock { $0 += delta }
    }
}
