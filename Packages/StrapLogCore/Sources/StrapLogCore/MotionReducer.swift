/// Reduces the strap's accelerometer stream (25 Hz, mg) to one `MotionSecond` per
/// wall-clock second, so a night costs ~29 k small rows instead of ~720 k samples.
/// Pure and incremental: feed batches as they arrive, `flush` the partial last second on Stop.
public struct MotionReducer: Sendable {
    public static let gravityMg = 1000.0
    /// Sample spacing assumed when a batch's device timestamps are missing or not increasing.
    public static let nominalPeriodMs = 40.0

    public let recordingId: Int64
    private var bucket: MotionBucket?
    /// Latest sample time handed out; later samples are clamped to it, keeping time monotonic
    /// when receipt jitter would place a batch's first samples before the previous batch's last.
    private var lastMs: Int64?

    public init(recordingId: Int64) {
        self.recordingId = recordingId
    }

    /// Adds one notification's samples; returns the seconds they completed, oldest first.
    public mutating func add(receivedAtMs: Int64, samples: [AccSample]) -> [MotionSecond] {
        var done: [MotionSecond] = []
        for (sample, t) in zip(samples, Self.timesMs(receivedAtMs: receivedAtMs, samples: samples)) {
            let t = max(t, lastMs ?? t)
            lastMs = t
            let second = t - ((t % 1000) + 1000) % 1000
            if let open = bucket, open.secondMs != second {
                done.append(open.second(recordingId: recordingId))
                bucket = nil
            }
            bucket = (bucket ?? MotionBucket(secondMs: second)).adding(sample)
        }
        return done
    }

    /// The partial second in progress, if any; the reducer is then empty.
    public mutating func flush() -> MotionSecond? {
        defer { bucket = nil }
        return bucket?.second(recordingId: recordingId)
    }

    /// Wall-clock ms per sample: the last sample is taken to arrive at `receivedAtMs`, earlier
    /// ones are placed back by their device-clock offsets (or the nominal period if unusable).
    public static func timesMs(receivedAtMs: Int64, samples: [AccSample]) -> [Int64] {
        guard let last = samples.last else { return [] }
        let increasing = zip(samples, samples.dropFirst()).allSatisfy { $0.deviceNs < $1.deviceNs }
        return samples.enumerated().map { i, s in
            let backMs = increasing
                ? Double(last.deviceNs - s.deviceNs) / 1_000_000
                : Double(samples.count - 1 - i) * nominalPeriodMs
            return receivedAtMs - Int64(backMs.rounded())
        }
    }
}
