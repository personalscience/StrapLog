/// Turns per-second postures into confirmed posture changes. A new posture counts once it has
/// held for `holdMs` without a contrary second, and is dated from its first second, so turning
/// over or bending to pick something up does not flap. Pure and incremental, like `MotionReducer`.
public struct PostureTracker: Sendable {
    public struct Change: Sendable, Equatable {
        public var atMs: Int64
        public var posture: Posture
    }

    public static let defaultHoldMs: Int64 = 60_000

    public let holdMs: Int64
    /// The confirmed posture, nil until one has held for `holdMs`.
    public private(set) var posture: Posture?
    /// When the confirmed posture began.
    public private(set) var sinceMs: Int64?
    /// Whether `lying` has ever been confirmed: sitting up in bed before lying down is not waking.
    public private(set) var hasLain = false
    /// End of the latest second seen.
    public private(set) var latestMs: Int64?
    private var candidate: Change?

    public init(holdMs: Int64 = PostureTracker.defaultHoldMs) {
        self.holdMs = holdMs
    }

    /// Adds seconds oldest first; returns the changes they confirm.
    public mutating func add(_ seconds: [MotionSecond]) -> [Change] {
        seconds.compactMap { add($0) }
    }

    /// How long the body has been upright after having lain down, as of the latest second; 0 otherwise.
    public var uprightAfterLyingMs: Int64 {
        guard hasLain, posture == .upright, let sinceMs, let latestMs else { return 0 }
        return latestMs - sinceMs
    }

    private mutating func add(_ second: MotionSecond) -> Change? {
        latestMs = second.secondMs + 1000
        guard let p = Posture.of(second) else { return nil }
        guard p != posture else { candidate = nil; return nil }
        let pending = candidate?.posture == p ? candidate! : Change(atMs: second.secondMs, posture: p)
        guard second.secondMs + 1000 - pending.atMs >= holdMs else { candidate = pending; return nil }
        candidate = nil
        posture = p
        sinceMs = pending.atMs
        if p == .lying { hasLain = true }
        return pending
    }
}
