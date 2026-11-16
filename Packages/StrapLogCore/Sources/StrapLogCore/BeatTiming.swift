/// Per-beat arithmetic for an HR notification. The H10 sends RR in 1/1024 s with
/// no device timestamp, so each beat's end time is estimated back from receipt.
public enum BeatTiming {
    /// Milliseconds to the nearest 1/1024 s, for a sensor that sends RR in ms (the armband,
    /// straplog-d1h); off by at most 0.49 ms.
    public static func rr1024(fromMs ms: Int) -> Int {
        Int((Double(ms) * 1024 / 1000).rounded())
    }

    /// `rr_1024 * 1000 / 1024`. Exact in binary floating point (÷1024 is a power of two).
    public static func ms(fromRR1024 rr: Int) -> Double {
        Double(rr) * 1000 / 1024
    }

    /// `t_end_ms_est` for each RR: the last beat ends at `receivedAtMs`; earlier beats end
    /// earlier by the sum of the RRs after them. The sum is taken in 1/1024 s and rounded once.
    public static func endTimesMs(receivedAtMs: Int64, rr1024: [Int]) -> [Int64] {
        var later = 0
        var out = [Int64](repeating: 0, count: rr1024.count)
        for i in rr1024.indices.reversed() {
            out[i] = receivedAtMs - Int64((Double(later) * 1000 / 1024).rounded())
            later += rr1024[i]
        }
        return out
    }

    /// The notification's beats, oldest first, each with its `endTimesMs` end time.
    public static func beats(receivedAtMs: Int64, rr1024: [Int]) -> [TimedBeat] {
        zip(rr1024, endTimesMs(receivedAtMs: receivedAtMs, rr1024: rr1024)).map { TimedBeat(rr1024: $0, tEndMs: $1) }
    }
}
