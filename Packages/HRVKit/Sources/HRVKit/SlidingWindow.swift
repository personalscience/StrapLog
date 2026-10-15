import Foundation

/// A value stamped with a time in seconds.
public struct TimedSample<Value: Sendable>: Sendable {
    public let t: Double
    public let value: Value

    public init(t: Double, value: Value) {
        self.t = t
        self.value = value
    }
}

extension TimedSample: Equatable where Value: Equatable {}

/// One window produced by `SlidingWindow`: samples with `lower <= t < upper`.
public struct WindowSlice<Value: Sendable>: Sendable {
    public let center: Double
    public let samples: ArraySlice<TimedSample<Value>>

    public var values: [Value] { samples.map(\.value) }
}

/// Fixed-length time windows advanced by a fixed stride, with the window placement
/// of `rolling_features` in analyze_h10.py: centers are
/// `np.arange(width/2, tEnd - width/2 + 1, stride)` and membership is half-open.
public struct SlidingWindow: Sendable {
    public let width: Double
    public let stride: Double

    public init(width: Double = HRVDefaults.windowSeconds, stride: Double = HRVDefaults.strideSeconds) {
        precondition(width > 0 && stride > 0, "window width and stride must be positive")
        self.width = width
        self.stride = stride
    }

    /// Window centers for a recording whose last sample is at `tEnd`.
    public func centers(tEnd: Double) -> [Double] {
        let start = width / 2, stop = tEnd - width / 2 + 1
        guard stop > start else { return [] }
        let count = Int(((stop - start) / stride).rounded(.up))   // numpy arange length
        return (0..<count).map { start + Double($0) * stride }
    }

    /// Windows over `samples`, which must be sorted by `t` (time zero = first sample's clock).
    public func windows<Value>(over samples: [TimedSample<Value>]) -> [WindowSlice<Value>] {
        guard let last = samples.last else { return [] }
        return centers(tEnd: last.t).map { c in
            let lo = lowerBound(samples, c - width / 2)
            let hi = lowerBound(samples, c + width / 2)
            return WindowSlice(center: c, samples: samples[lo..<hi])
        }
    }

    /// First index whose `t >= bound`.
    private func lowerBound<Value>(_ s: [TimedSample<Value>], _ bound: Double) -> Int {
        var lo = 0, hi = s.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if s[mid].t < bound { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}
