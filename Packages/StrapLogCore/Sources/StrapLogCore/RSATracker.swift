import HRVKit

/// Respiratory sinus arrhythmia live: heart rate following the pacer's breath (straplog-9fr).
/// Keeps the last `RSADefaults.contextSeconds` of beats and cleans them with `RRCleaner` on
/// every beat; each kept beat is an HR sample at its mid-interval (`InstantHR`). As each pacer
/// breath ends it closes one `BreathSwing` and refits the cosinor over the last
/// `RSADefaults.windowBreaths` whole breaths. Built per pacer, like `BreathTracker`: a rate
/// change is a new pacer and so a cold start. A beat gap over `gapMs` starts afresh.
public struct RSATracker: Sendable {
    /// Longer than this between beat end times, and the tracker forgets everything before.
    public static let gapMs: Int64 = 5_000
    /// Breaths a reading carries (the bars).
    public static let keptBreaths = 12
    /// Whole breaths before a reading stops warming up.
    public static let warmUpBreaths = 2
    /// Beats that must end past a breath before it closes, so the cleaner's centred 5-beat
    /// median has seen the neighbours of the breath's last beats.
    public static let settleBeats = 2

    private let pacer: BreathingPacer
    /// Beats in arrival order, the last `contextSeconds`.
    private var tEndMs: [Int64] = []
    private var rrMs: [Double] = []
    /// The next pacer breath to close; the first is the first one the beats cover whole.
    private var nextBreath: Int?
    private var breaths: [BreathSwing] = []
    private var closed = 0
    private var fit: CosinorFit?
    private var trace: [TrendPoint] = []

    public init(pacer: BreathingPacer) {
        self.pacer = pacer
    }

    /// Adds one beat (`TimedBeat`'s end time and RR); returns the reading as of it.
    public mutating func add(tEndMs t: Int64, rrMs rr: Double) -> RSAReading? {
        if let last = tEndMs.last, t - last > Self.gapMs { self = RSATracker(pacer: pacer) }
        tEndMs.append(t)
        rrMs.append(rr)
        let cutoff = t - Int64(RSADefaults.contextSeconds * 1000)
        if let keep = tEndMs.firstIndex(where: { $0 >= cutoff }), keep > 0 {
            tEndMs.removeFirst(keep)
            rrMs.removeFirst(keep)
        }
        if nextBreath == nil { nextBreath = firstWholeBreath(beatStartMs: t - Int64(rr.rounded())) }

        let samples = InstantHR.samples(rrMs: rrMs, tEndS: tEndMs.map(seconds))
        let traceFrom = seconds(t) - RSADefaults.traceSeconds
        trace = samples.filter { $0.t >= traceFrom }.map {
            TrendPoint(atMs: pacer.startedAtMs + Int64(($0.t * 1000).rounded()), value: $0.value)
        }
        while let k = nextBreath, beatsEnded(atOrAfterMs: pacer.breathStartMs(k + 1)) >= Self.settleBeats {
            close(k, samples)
            nextBreath = k + 1
        }
        return reading
    }

    /// The reading as of the latest beat; nil before any.
    public var reading: RSAReading? {
        guard let atMs = tEndMs.last else { return nil }
        return RSAReading(atMs: atMs, trace: trace, breaths: breaths, fit: fit,
                          warmingUp: closed < Self.warmUpBreaths)
    }

    private mutating func close(_ k: Int, _ samples: [TimedSample<Double>]) {
        breaths.append(BreathSwing(samples, startS: breathStartS(k), endS: breathStartS(k + 1)))
        if breaths.count > Self.keptBreaths { breaths.removeFirst(breaths.count - Self.keptBreaths) }
        closed += 1
        guard closed >= RSADefaults.windowBreaths else { return }
        fit = Cosinor.fit(samples, periodS: pacer.periodMs / 1000,
                          fromS: breathStartS(k + 1 - RSADefaults.windowBreaths))
    }

    /// The first breath that starts no earlier than the first beat's interval.
    private func firstWholeBreath(beatStartMs: Int64) -> Int {
        let k = pacer.breathIndex(atMs: beatStartMs)
        return pacer.breathStartMs(k) >= beatStartMs ? k : k + 1
    }

    private func beatsEnded(atOrAfterMs boundary: Int64) -> Int {
        tEndMs.reversed().prefix { $0 >= boundary }.count
    }

    private func seconds(_ ms: Int64) -> Double { Double(ms - pacer.startedAtMs) / 1000 }

    private func breathStartS(_ k: Int) -> Double { seconds(pacer.breathStartMs(k)) }
}
