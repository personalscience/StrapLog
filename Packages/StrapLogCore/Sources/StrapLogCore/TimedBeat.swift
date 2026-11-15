/// One RR interval with its estimated end time, as `BeatTiming.beats` expands an HR
/// notification: what live consumers (and the `beat` rows) are built from.
public struct TimedBeat: Sendable, Equatable {
    /// The RR as the strap sent it, in 1/1024 s.
    public let rr1024: Int
    /// `t_end_ms_est`: Unix epoch ms UTC.
    public let tEndMs: Int64

    public init(rr1024: Int, tEndMs: Int64) {
        self.rr1024 = rr1024
        self.tEndMs = tEndMs
    }

    public var rrMs: Double { BeatTiming.ms(fromRR1024: rr1024) }
}
