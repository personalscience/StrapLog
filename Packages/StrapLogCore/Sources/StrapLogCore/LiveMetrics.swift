import HRVKit

/// Rolling HRV for the recording screen, fed one beat at a time.
///
/// Uses the same 120 s windows as `WindowAnalyzer.features` (time zero at the first beat) but
/// advances them every `liveStrideSeconds` so α1 reacts sooner; every third window is one of
/// the skills' 60 s-stride windows. Works incrementally: each window is analysed once, when
/// the first beat at or past its end arrives, and only beats still inside an open window are
/// kept. So the windows here are exactly the batch windows that the beats so far have closed.
/// Display only: nothing here is stored.
public struct LiveMetrics: Sendable {
    /// Display stride: three live windows per batch stride.
    public static let liveStrideSeconds = 20.0
    /// Default `historySpanMs`: longer than any planned recording.
    public static let defaultHistorySpanMs: Int64 = 12 * 3_600_000

    public let analyzer: WindowAnalyzer
    /// How much RR history `rrHistory` keeps.
    public let historySpanMs: Int64
    /// `t_end_ms_est` of the first beat: time zero for the windows.
    public private(set) var originMs: Int64?
    /// Raw RR (ms) over the last `historySpanMs`, oldest first.
    public private(set) var rrHistory: [TrendPoint] = []
    /// Every closed window with enough beats, as `WindowAnalyzer.features` returns them.
    public private(set) var windows: [WindowFeatures] = []
    /// The most recently closed window, or nil if it had too few beats (or none has closed).
    public private(set) var latest: WindowFeatures?
    /// Number of windows closed so far, including those with too few beats.
    public private(set) var closedWindows = 0

    /// Beats (seconds since `originMs`) that may still belong to an open window.
    private var pending: [TimedSample<Double>] = []

    public init(analyzer: WindowAnalyzer = WindowAnalyzer(window: SlidingWindow(stride: LiveMetrics.liveStrideSeconds)),
                historySpanMs: Int64 = LiveMetrics.defaultHistorySpanMs) {
        self.analyzer = analyzer
        self.historySpanMs = historySpanMs
    }

    /// α1 of each window, stamped at the window's end: the moment the value became known.
    public var alpha1History: [TrendPoint] {
        guard let originMs else { return [] }
        let half = analyzer.window.width / 2
        return windows.compactMap { w in
            w.alpha1.map { TrendPoint(atMs: originMs + Int64((w.tCenter + half) * 1000), value: $0) }
        }
    }

    /// The newest α1 value and when it became known, even if later windows had too few beats.
    public var lastAlpha1: TrendPoint? {
        guard let originMs, let w = windows.last(where: { $0.alpha1 != nil }), let a = w.alpha1 else { return nil }
        return TrendPoint(atMs: originMs + Int64((w.tCenter + analyzer.window.width / 2) * 1000), value: a)
    }

    /// Instantaneous HR (60000 / RR) of every beat in `rrHistory`.
    public var hrHistory: [TrendPoint] {
        rrHistory.map { TrendPoint(atMs: $0.atMs, value: 60_000 / $0.value) }
    }

    /// End time (epoch ms) of the most recently closed window, or nil before the first closes.
    public var latestWindowEndMs: Int64? {
        guard let originMs, closedWindows > 0 else { return nil }
        return originMs + Int64(analyzer.window.upper(ofWindow: closedWindows - 1) * 1000)
    }

    /// Adds one beat. Beats must arrive in recording order (`beat.id`).
    public mutating func add(tEndMs: Int64, rrMs: Double) {
        let origin = originMs ?? tEndMs
        originMs = origin
        let t = Double(tEndMs - origin) / 1000

        let window = analyzer.window
        while t >= window.upper(ofWindow: closedWindows) {
            close(window: closedWindows)
        }
        pending.append(TimedSample(t: t, value: rrMs))

        rrHistory.append(TrendPoint(atMs: tEndMs, value: rrMs))
        let cutoff = tEndMs - historySpanMs
        if let first = rrHistory.first, first.atMs < cutoff,
           let keep = rrHistory.firstIndex(where: { $0.atMs >= cutoff }) {
            rrHistory.removeFirst(keep)
        }
    }

    public mutating func add(_ beat: Beat) {
        add(tEndMs: beat.tEndMsEst, rrMs: beat.rrMs)
    }

    private mutating func close(window k: Int) {
        let w = analyzer.window
        let (lo, hi) = (w.lower(ofWindow: k), w.upper(ofWindow: k))
        let raw = pending.filter { $0.t >= lo && $0.t < hi }.map(\.value)
        latest = analyzer.features(of: raw, center: w.center(ofWindow: k))
        if let latest { windows.append(latest) }
        closedWindows = k + 1
        let nextLo = w.lower(ofWindow: closedWindows)
        pending.removeAll { $0.t < nextLo }
    }
}
