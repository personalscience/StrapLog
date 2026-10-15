import Foundation

/// The device clock and current time zone.
public struct SystemClock: WallClock {
    public init() {}

    public func nowMs() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    public func tzOffsetSeconds(atMs ms: Int64) -> Int {
        TimeZone.current.secondsFromGMT(for: Date(timeIntervalSince1970: Double(ms) / 1000))
    }
}
