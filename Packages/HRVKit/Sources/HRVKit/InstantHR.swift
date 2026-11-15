/// Beat-to-beat heart rate for RSA: each beat that survives `RRCleaner` gives
/// `60000 / rr` bpm at the middle of its interval, `tEnd − rr/2`. Dropped beats
/// leave a hole; nothing is interpolated.
public enum InstantHR {
    /// `rrMs[i]` ends at `tEndS[i]` (seconds). Returns samples in beat order.
    public static func samples(rrMs: [Double], tEndS: [Double],
                               cleaner: RRCleaner = RRCleaner()) -> [TimedSample<Double>] {
        precondition(rrMs.count == tEndS.count, "one end time per RR interval")
        let removed = Set(cleaner.clean(rrMs).removedIndices)
        return rrMs.indices.filter { !removed.contains($0) }.map {
            TimedSample(t: tEndS[$0] - rrMs[$0] / 2000, value: 60000 / rrMs[$0])
        }
    }
}
