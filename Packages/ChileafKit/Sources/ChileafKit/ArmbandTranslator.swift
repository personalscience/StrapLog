import StrapLogCore

/// Turns the band's notifications into `SensorEvent`s, as `PolarHeartSource` does for the H10.
/// The band sends one accelerometer sample per notification (~50/s) and one PPG reading per
/// notification (~32/s); passing each on alone would mean ~80 events and ~32 database writes a
/// second, so both are batched and flushed with every HR notification (~1/s) or when a batch
/// fills. Not thread-safe: the source calls it from its one Bluetooth queue.
public struct ArmbandTranslator: Sendable {
    /// The band's accelerometer rate. Its firmware is `4.2.2_50Hz`, and the 11-03 and 11-10
    /// captures measure 49.8–50.5 frames/s.
    public static let accelHz = 50
    /// Flush a batch once it holds this many samples, even before the next HR notification.
    static let maxAccel = 50
    static let maxPpg = 32

    private var accel: [AccSample] = []
    private var accelAtMs: Int64 = 0
    /// Samples since connection: the synthetic device clock. Receipt times come in bursts of
    /// several frames per millisecond, so the band's steady rate is the better clock.
    private var accelCount: UInt64 = 0
    private var ppg: [PpgSample] = []
    private var ppgAtMs: Int64 = 0
    private var dedupe = PpgDeduper()

    public init() {}

    /// Call on every (re)connection: counters and the sample clock start afresh.
    public mutating func connected() {
        accel = []
        ppg = []
        accelCount = 0
        dedupe.reset()
    }

    /// One 0x2A37 notification: flushes the batches first, so stored times stay in order. The
    /// band's RR milliseconds become the 1/1024 s every `SensorEvent` carries.
    public mutating func heartRate(_ bytes: [UInt8], atMs: Int64) -> [SensorEvent] {
        guard let m = HeartRateMeasurement(bytes) else { return flush() }
        let rr1024 = m.rrMs.map(BeatTiming.rr1024(fromMs:))
        return flush() + [SensorEvent(atMs: atMs, .heartRate(bpm: m.bpm, contact: m.contact, rr1024: rr1024))]
    }

    /// One `aae28f01` notification. Accelerometer samples are batched; a temperature passes
    /// straight through (1/s); other frame types are dropped for now.
    public mutating func vendorFrame(_ bytes: [UInt8], atMs: Int64) -> [SensorEvent] {
        switch VendorFrame.parse(bytes) {
        case .accel(let counts): return accelSample(counts, atMs: atMs)
        case .temperature(let t): return [SensorEvent(atMs: atMs, .temperature(t))]
        case .other, nil: return []
        }
    }

    private mutating func accelSample(_ counts: AccelCounts, atMs: Int64) -> [SensorEvent] {
        let mg = counts.milliG
        accel.append(AccSample(deviceNs: accelCount * 1_000_000_000 / UInt64(Self.accelHz), x: mg.x, y: mg.y, z: mg.z))
        accelCount += 1
        accelAtMs = atMs
        return accel.count >= Self.maxAccel ? flushAccel() : []
    }

    /// One `aae21542` notification; re-sent packets are dropped here.
    public mutating func ppgPacket(_ bytes: [UInt8], atMs: Int64) -> [SensorEvent] {
        guard let p = PpgPacket(bytes), dedupe.accept(p.counter) else { return [] }
        ppg.append(PpgSample(receivedAtMs: atMs, counter: Int(p.counter), value: p.value))
        ppgAtMs = atMs
        return ppg.count >= Self.maxPpg ? flushPpg() : []
    }

    /// Whatever is batched, e.g. before a disconnect is reported.
    public mutating func flush() -> [SensorEvent] {
        flushAccel() + flushPpg()
    }

    /// Dated at the newest sample's receipt: `MotionReducer` places the batch back from there.
    private mutating func flushAccel() -> [SensorEvent] {
        guard !accel.isEmpty else { return [] }
        defer { accel = [] }
        return [SensorEvent(atMs: accelAtMs, .motion(samples: accel))]
    }

    private mutating func flushPpg() -> [SensorEvent] {
        guard !ppg.isEmpty else { return [] }
        defer { ppg = [] }
        return [SensorEvent(atMs: ppgAtMs, .ppg(samples: ppg))]
    }
}
