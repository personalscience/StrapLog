/// The last few seconds of live ECG, on the phone's clock, with the R peaks found in it. For
/// display only: nothing here is written to the database.
///
/// The strap's clock runs on its own epoch, so each batch offers an offset (receipt time minus
/// the batch's last sample); the smallest seen is the one with the least Bluetooth delay, and is
/// kept. A strap clock that jumps (a reconnect) starts the trace over.
public struct EcgTrace: Sendable {
    public struct Point: Sendable, Equatable {
        public let atMs: Double
        public let microvolts: Int
    }

    /// How much history is kept.
    public static let keepMs = 8_000.0
    /// An offset this much worse than the best so far means the strap clock moved.
    static let clockJumpMs = 2_000.0

    /// Strap time in ms, with `offsetMs` added on read.
    private var samples: [(deviceMs: Double, microvolts: Int)] = []
    private var beatsDeviceMs: [Double] = []
    private var offsetMs: Double?
    private var detector = RPeakDetector()

    public init() {}

    public var isEmpty: Bool { samples.isEmpty }

    public mutating func add(_ batch: [EcgSample], receivedAtMs: Int64) {
        guard let last = batch.last else { return }
        let candidate = Double(receivedAtMs) - Self.ms(last.deviceNs)
        if let offset = offsetMs, candidate > offset + Self.clockJumpMs || candidate < offset - Self.clockJumpMs {
            self = EcgTrace()
        }
        offsetMs = min(offsetMs ?? candidate, candidate)
        for sample in batch {
            let deviceMs = Self.ms(sample.deviceNs)
            samples.append((deviceMs, sample.microvolts))
            if let beat = detector.add(atMs: deviceMs, value: Double(sample.microvolts)) { beatsDeviceMs.append(beat) }
        }
        let cutoff = Self.ms(last.deviceNs) - Self.keepMs
        samples.removeFirst(samples.prefix { $0.deviceMs < cutoff }.count)
        beatsDeviceMs.removeFirst(beatsDeviceMs.prefix { $0 < cutoff }.count)
    }

    /// Samples at or after `fromMs` (phone time), oldest first.
    public func points(fromMs: Double) -> [Point] {
        guard let offsetMs else { return [] }
        return samples.lazy.filter { $0.deviceMs + offsetMs >= fromMs }
            .map { Point(atMs: $0.deviceMs + offsetMs, microvolts: $0.microvolts) }
    }

    /// R peaks, phone time, oldest first.
    public var beatsMs: [Double] {
        guard let offsetMs else { return [] }
        return beatsDeviceMs.map { $0 + offsetMs }
    }

    /// The pulse from the last two R peaks, or nil before there are two.
    public var pulse: BeatPulse? {
        let beats = beatsMs
        guard beats.count >= 2 else { return nil }
        return BeatPulse(lastBeatMs: beats[beats.count - 1], rrMs: beats[beats.count - 1] - beats[beats.count - 2])
    }

    private static func ms(_ ns: UInt64) -> Double { Double(ns) / 1_000_000 }
}
