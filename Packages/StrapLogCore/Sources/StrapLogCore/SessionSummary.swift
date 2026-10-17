import GRDB
import HRVKit

/// The end-of-session numbers for one recording, from its stored beats with HRVKit's
/// skill-matching defaults. The whole series is cleaned once for artifacts, mean HR and RMSSD
/// (the fixtures' `clean` block); the skills' 120 s / 60 s windows give the lowest HR and minutes
/// per α1 band, each window with an α1 counting one stride. Display only: nothing here is stored.
public struct SessionSummary: Sendable, Equatable {
    /// Start to stop; nil while the recording is open.
    public var durationMs: Int64?
    public var beats: Int
    /// `Coverage.fraction`.
    public var coverage: Double
    /// 60000 / mean cleaned RR, i.e. time-weighted; nil with no clean beats.
    public var meanHR: Double?
    /// Lowest window mean HR: a 2-min average, so one missed beat cannot fake a low.
    /// Nil until a window has enough beats.
    public var lowestHR: Double?
    /// RMSSD of the whole cleaned series.
    public var rmssd: Double?
    /// Share of beats `RRCleaner` removed; nil with no beats.
    public var artifactRate: Double?
    /// Minutes per α1 band; a band with no windows is absent.
    public var alpha1Minutes: [Alpha1Band: Double]

    /// `rrMs` and `tEndMs` are the beats in recording order; window time zero is the first beat.
    public init(rrMs: [Double], tEndMs: [Int64], durationMs: Int64?, coverage: Double,
                analyzer: WindowAnalyzer = WindowAnalyzer()) {
        let cleaning = analyzer.cleaner.clean(rrMs)
        let clean = cleaning.kept
        self.durationMs = durationMs
        self.coverage = coverage
        beats = rrMs.count
        meanHR = TimeDomain.meanHR(clean)
        rmssd = TimeDomain.rmssd(clean)
        artifactRate = cleaning.artifactRate

        let origin = tEndMs.first ?? 0
        let timed = zip(tEndMs, rrMs).map { TimedSample(t: Double($0 - origin) / 1000, value: $1) }
        let windows = analyzer.features(timed)
        lowestHR = windows.map(\.hrBpm).min()
        let minutesPerWindow = analyzer.window.stride / 60
        alpha1Minutes = windows.compactMap(\.alpha1)
            .reduce(into: [:]) { $0[Alpha1Band(alpha1: $1), default: 0] += minutesPerWindow }
    }

    /// The summary of `recording` from its beats.
    public init(_ recording: Recording, beats: [Beat], coverage: Coverage) {
        self.init(rrMs: beats.map(\.rrMs), tEndMs: beats.map(\.tEndMsEst),
                  durationMs: recording.endedAtMs.map { $0 - recording.startedAtMs },
                  coverage: coverage.fraction)
    }
}
