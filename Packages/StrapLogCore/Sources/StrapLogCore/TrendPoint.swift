import Foundation

/// One timestamped value for a live chart: a raw RR interval, an HR, or a window's α1.
public struct TrendPoint: Sendable, Equatable {
    /// Unix epoch ms UTC.
    public let atMs: Int64
    public let value: Double

    public init(atMs: Int64, value: Double) {
        self.atMs = atMs
        self.value = value
    }

    public var date: Date { Date(timeIntervalSince1970: Double(atMs) / 1000) }
}
