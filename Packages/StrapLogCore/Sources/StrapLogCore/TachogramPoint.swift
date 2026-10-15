import Foundation

/// One raw RR interval for the tachogram, stamped with its estimated end time.
public struct TachogramPoint: Sendable, Equatable {
    /// `t_end_ms_est`, Unix epoch ms UTC.
    public let atMs: Int64
    public let rrMs: Double

    public init(atMs: Int64, rrMs: Double) {
        self.atMs = atMs
        self.rrMs = rrMs
    }

    public var date: Date { Date(timeIntervalSince1970: Double(atMs) / 1000) }
}
