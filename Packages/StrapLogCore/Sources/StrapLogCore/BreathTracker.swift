/// Live breathing from the strap's accelerometer (straplog-cef). The chest's rise and fall tilts
/// the strap, so the gravity vector it reads swings with each breath, tens of mg against
/// ~1000. Per sample: a band-pass (a slow baseline taken away, then a gentle low-pass) leaves
/// the breathing swing; `PrincipalAxis` finds the direction it swings along, and the projection
/// onto it is the breath. Which end is "in" depends on posture and strap placement, so the sign
/// is calibrated against the pacer the user is following: the first `calibrateMs` in which
/// projection and paced lung fill correlate by `calibrateR`. Lung fill is then the projection
/// scaled to its range over the last `envelopeMs`.
///
/// Movement swamps all of this: fast jitter or a big swing (turning, reaching) resets the
/// axis and calibration and reads as not `still`. Pure and incremental, like `MotionReducer`.
public struct BreathTracker: Sendable {
    /// Below breathing (3/min is 0.05 Hz): the baseline taken away. Low, because it leads the
    /// phase: 0.02 Hz puts the bubble ~0.3 s ahead at 6/min, ~0.5 s at 4.5/min.
    public static let baselineHz = 0.02
    /// Above breathing, below the heart's thump.
    public static let smoothHz = 0.7
    /// What counts as jitter: everything above this.
    public static let jitterHz = 2.0
    public static let axisTauMs = 30_000.0
    public static let calibrateMs: Int64 = 20_000
    public static let calibrateR = 0.3
    public static let envelopeMs: Int64 = 20_000
    public static let inStepMs: Int64 = 60_000
    /// Correlation needs this much history before `inStep` is reported.
    public static let inStepMinMs: Int64 = 30_000
    /// History spacing for the envelope and `inStep`.
    public static let historyStepMs: Int64 = 200
    /// RMS of jitter (mg) above which the body is moving.
    public static let jitterLimitMg = 50.0
    /// A band-passed swing (mg) this big is a posture change, not a breath (breaths are ~70 mg peak to peak).
    public static let swingLimitMg = 300.0
    /// Smallest breath range (mg) worth scaling up to the full bubble.
    public static let minRangeMg = 4.0
    /// A gap in the samples this long starts everything afresh.
    public static let gapMs: Int64 = 3_000

    private let pacer: BreathingPacer
    private var lastMs: Int64?
    private var baseline = OnePole(cutoffHz: BreathTracker.baselineHz)
    private var smooth = OnePole(cutoffHz: BreathTracker.smoothHz)
    private var fast = OnePole(cutoffHz: BreathTracker.jitterHz)
    /// Mean square of the jitter, smoothed over about a second.
    private var jitterSq = 0.0
    private var axis = PrincipalAxis(tauMs: BreathTracker.axisTauMs)
    /// +1 or -1 once calibrated: which way along the axis is "in".
    private var sign: Double?
    private var calibration = Correlation()
    private var calibrationFromMs: Int64?
    /// Projection and paced lung fill every `historyStepMs`, oldest first, the last `inStepMs`.
    private var history: [(atMs: Int64, projection: Double, paced: Double)] = []
    private var still = true
    /// The latest sample's projection (history is sparser).
    private var projection: Double?

    /// Tracks breathing against `pacer`, which supplies the calibration and `inStep`.
    public init(pacer: BreathingPacer) {
        self.pacer = pacer
    }

    /// Adds one accelerometer notification; returns the reading as of its last sample.
    public mutating func add(receivedAtMs: Int64, samples: [AccSample]) -> BreathReading? {
        for (sample, t) in zip(samples, MotionReducer.timesMs(receivedAtMs: receivedAtMs, samples: samples)) {
            add(SIMD3(Double(sample.x), Double(sample.y), Double(sample.z)), atMs: t)
        }
        return reading
    }

    /// The reading as of the latest sample; nil before any.
    public var reading: BreathReading? {
        guard let lastMs else { return nil }
        return BreathReading(atMs: lastMs, volume: still ? volume : nil, still: still,
                             inStep: still ? inStep : nil)
    }

    private mutating func add(_ v: SIMD3<Double>, atMs rawMs: Int64) {
        let t = max(rawMs, lastMs ?? rawMs)
        if let lastMs, t - lastMs > Self.gapMs { self = BreathTracker(pacer: pacer) }
        let dtMs = Double(max(1, t - (lastMs ?? t)))
        lastMs = t

        let jitter = v - fast.step(v, dtMs: dtMs)
        jitterSq += ((jitter * jitter).sum() - jitterSq) * (dtMs / (1000 + dtMs))
        let band = smooth.step(v - baseline.step(v, dtMs: dtMs), dtMs: dtMs)
        guard jitterSq.squareRoot() <= Self.jitterLimitMg,
              (band * band).sum().squareRoot() <= Self.swingLimitMg else {
            moved(to: v)
            return
        }
        still = true
        let projection = axis.add(band, dtMs: dtMs)
        self.projection = projection
        let paced = pacer.phase(atMs: t).volume
        calibrate(projection, paced, atMs: t)
        if history.last.map({ t - $0.atMs >= Self.historyStepMs }) ?? true {
            history.append((t, projection, paced))
            let cutoff = t - Self.inStepMs
            if let first = history.firstIndex(where: { $0.atMs >= cutoff }), first > 0 {
                history.removeFirst(first)
            }
        }
    }

    /// Movement: the filters restart from here so the swing does not ring on, and the axis,
    /// sign and history are learnt again, since a new posture tilts the strap another way.
    private mutating func moved(to v: SIMD3<Double>) {
        still = false
        baseline.snap(to: v)
        smooth.snap(to: SIMD3())
        axis = PrincipalAxis(tauMs: Self.axisTauMs)
        sign = nil
        calibration = Correlation()
        calibrationFromMs = nil
        history = []
        projection = nil
    }

    private mutating func calibrate(_ projection: Double, _ paced: Double, atMs t: Int64) {
        guard sign == nil else { return }
        let from = calibrationFromMs ?? t
        calibrationFromMs = from
        calibration.add(projection, paced)
        guard t - from >= Self.calibrateMs else { return }
        if let r = calibration.r, abs(r) >= Self.calibrateR {
            sign = r > 0 ? 1 : -1
        } else if t - from >= 2 * Self.calibrateMs {
            // Not following yet: judge afresh rather than let the start weigh forever.
            calibration = Correlation()
            calibrationFromMs = t
        }
    }

    private var volume: Double? {
        guard let sign, let projection, let lastMs else { return nil }
        let recent = history.lazy.filter { lastMs - $0.atMs <= Self.envelopeMs }.map { $0.projection * sign }
        guard let low = recent.min(), let high = recent.max(), high - low >= Self.minRangeMg else { return nil }
        return min(1, max(0, (projection * sign - low) / (high - low)))
    }

    private var inStep: Double? {
        guard let sign, let first = history.first, let last = history.last,
              last.atMs - first.atMs >= Self.inStepMinMs else { return nil }
        return Correlation(history.map { ($0.projection * sign, $0.paced) }).r
    }
}
