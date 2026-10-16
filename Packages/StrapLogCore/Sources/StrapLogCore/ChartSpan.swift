import Foundation

/// How much of the recording the live chart shows, ending now. Pinching walks the steps.
public enum ChartSpan: Int, CaseIterable, Sendable, Comparable {
    case oneMinute = 1, twoMinutes = 2, fiveMinutes = 5, fifteenMinutes = 15, thirtyMinutes = 30, hour = 60
    /// The whole recording so far.
    case all = 0

    public static let `default` = ChartSpan.fiveMinutes

    /// Fixed length in ms, or nil for `.all`.
    public var fixedMs: Int64? { self == .all ? nil : Int64(rawValue) * 60_000 }

    /// Visible length when the recording has run `elapsedMs`. `.all` never shows less than a minute.
    public func lengthMs(elapsedMs: Int64) -> Int64 {
        fixedMs ?? max(elapsedMs, ChartSpan.oneMinute.fixedMs!)
    }

    /// The step nearest (on a log scale) to this span divided by `magnification`:
    /// pinching out (> 1) zooms in to a shorter span, pinching in (< 1) zooms out.
    public func zoomed(by magnification: Double, elapsedMs: Int64) -> ChartSpan {
        guard magnification > 0 else { return self }
        let target = log(Double(lengthMs(elapsedMs: elapsedMs)) / magnification)
        // Ties go to the fixed step, so `.all` is reached only when it is truly longer.
        return Self.allCases.sorted().min { a, b in
            abs(log(Double(a.lengthMs(elapsedMs: elapsedMs))) - target)
                < abs(log(Double(b.lengthMs(elapsedMs: elapsedMs))) - target)
        } ?? self
    }

    /// Steps ordered by length, `.all` last.
    public static func < (a: ChartSpan, b: ChartSpan) -> Bool {
        (a.fixedMs ?? .max) < (b.fixedMs ?? .max)
    }
}
