import Foundation

/// Source of wall-clock time for everything the database stamps. Injectable so tests
/// control time; named `WallClock` because the standard library already owns `Clock`.
public protocol WallClock: Sendable {
    /// Unix epoch milliseconds, UTC.
    func nowMs() -> Int64
    /// Local offset from UTC at `ms`, in seconds (stored per recording as `tz_offset_s`).
    func tzOffsetSeconds(atMs ms: Int64) -> Int
}
