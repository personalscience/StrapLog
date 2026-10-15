import HRVKit

/// Rolling HRV for the recording screen, fed one beat at a time.
///
/// Uses the same windows as `WindowAnalyzer.features` (120 s, stride 60 s, time zero at the
/// first beat), but works incrementally: each window is analysed once, when the first beat
/// at or past its end arrives, and only beats still inside an open window are kept. So the
/// windows here are exactly the batch windows that the beats so far have closed.
public struct LiveMetrics: Sendable {
    /// How much RR history `tachogram` keeps.
    public static let tachogramSpanMs: Int64 = 5 * 60_000

    public let analyzer: WindowAnalyzer
    /// `t_end_ms_est` of the first beat: time zero for the windows.
    public private(set) var originMs: Int64?
    /// Raw RR over the last `tachogramSpanMs`, oldest first.
    public private(set) var tachogram: [TachogramPoint] = []
    /// Every closed window with enough beats, as `WindowAnalyzer.features` returns them.
    public private(set) var windows: [WindowFeatures] = []
    /// The most recently closed window, or nil if it had too few beats (or none has closed).
    public private(set) var latest: WindowFeatures?
    /// Number of windows closed so far, including those with too few beats.
    public private(set) var closedWindows = 0

    /// Beats (seconds since `originMs`) that may still belong to an open window.
    private var pending: [TimedSample<Double>] = []

    public init(analyzer: WindowAnalyzer = WindowAnalyzer()) {
        self.analyzer = analyzer
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

        tachogram.append(TachogramPoint(atMs: tEndMs, rrMs: rrMs))
        let cutoff = tEndMs - Self.tachogramSpanMs
        if let keep = tachogram.firstIndex(where: { $0.atMs >= cutoff }), keep > 0 {
            tachogram.removeFirst(keep)
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
