import Foundation

/// Finds R peaks in a streamed single-lead ECG, sample by sample: a slimmed Pan–Tompkins. The
/// slope (x[n] − x[n−2]) squared and averaged over ~60 ms rises sharply only in a QRS; a QRS
/// starts when that energy crosses a share of its recent peak and ends when it falls back, and
/// the R peak is the sample in that span furthest from the span's mean, whatever the lead's
/// polarity. T waves are too slow to cross. Times are whatever unit the caller feeds (ms).
public struct RPeakDetector: Sendable {
    /// Samples averaged for the energy (~60 ms at 130 Hz).
    static let window = 8
    /// The energy threshold, as a share of its decaying peak.
    static let thresholdShare = 0.3
    /// The peak halves over this long, so the threshold follows the signal's amplitude.
    static let peakHalfLifeMs = 2_000.0
    /// No two beats closer than this (200 bpm).
    static let refractoryMs = 300.0
    /// Energy is learned this long before any beat is reported.
    static let warmUpMs = 1_500.0
    /// A gap this long in the samples starts over.
    static let gapMs = 200.0
    /// Samples before the threshold crossing searched for the peak (the energy lags the slope).
    static let lookBack = 10

    private var times: [Double] = []
    private var values: [Double] = []
    private var energies: [Double] = []
    private var peakEnergy = 0.0
    private var startedAtMs: Double?
    private var qrsStart: Int?
    private var lastBeatMs: Double?

    public init() {}

    /// Feeds one sample; returns the time of an R peak when a QRS has just ended.
    public mutating func add(atMs: Double, value: Double) -> Double? {
        if let last = times.last, atMs - last > Self.gapMs || atMs <= last { self = RPeakDetector() }
        let previousAtMs = times.last
        times.append(atMs)
        values.append(value)
        startedAtMs = startedAtMs ?? atMs
        let n = values.count
        let slope = n >= 3 ? value - values[n - 3] : 0
        energies.append(slope * slope)
        let recent = energies.suffix(Self.window)
        let energy = recent.reduce(0, +) / Double(recent.count)
        let elapsed = previousAtMs.map { atMs - $0 } ?? 0
        peakEnergy = max(energy, peakEnergy * pow(0.5, elapsed / Self.peakHalfLifeMs))
        defer { trim() }

        guard atMs - startedAtMs! >= Self.warmUpMs else { return nil }
        let threshold = Self.thresholdShare * peakEnergy
        if let start = qrsStart {
            guard energy < threshold else { return nil }
            qrsStart = nil
            let span = max(0, start - Self.lookBack)..<n
            let mean = values[span].reduce(0, +) / Double(span.count)
            let peak = span.max { abs(values[$0] - mean) < abs(values[$1] - mean) }!
            if let lastBeatMs, times[peak] - lastBeatMs < Self.refractoryMs { return nil }
            lastBeatMs = times[peak]
            return times[peak]
        }
        if energy > threshold { qrsStart = n - 1 }
        return nil
    }

    /// Keeps a second or so of history; indices into it are rebased.
    private mutating func trim() {
        let keep = 160
        guard values.count > 2 * keep, qrsStart.map({ $0 > values.count - keep }) ?? true else { return }
        let drop = values.count - keep
        times.removeFirst(drop)
        values.removeFirst(drop)
        energies.removeFirst(drop)
        qrsStart = qrsStart.map { $0 - drop }
    }
}
