/// The last few seconds of raw PPG for the live waveform, plus a pulse-amplitude estimate. For
/// display only: storage is `RecordingSession`'s job.
///
/// Amplitude is the median, over the last few one-second windows, of each window's max − min.
/// A one-second window holds about one pulse at resting rates, so its range is roughly one
/// beat's peak-to-trough; the median shrugs off a window spoiled by movement. It is in the
/// sensor's raw units, so it is good for watching change within a session, not across bands.
public struct PpgTrace: Sendable {
    /// The armband's PPG rate (about 32 Hz); windows are counted in samples, since receipt
    /// times arrive in bursts.
    public static let sampleHz = 32
    /// How much waveform is kept.
    public static let keepSamples = 10 * sampleHz
    /// One-second windows in the amplitude median.
    static let amplitudeWindows = 5
    /// What the sensor reads off the skin (`PpgPacket`).
    public static let offSkinValue = 32767

    /// Raw values, oldest first, off-skin readings included.
    private var samples: [Int] = []

    public init() {}

    /// Whether the latest reading says the sensor is off the skin.
    public var offSkin: Bool { samples.last == Self.offSkinValue }

    /// On-skin values for drawing, oldest first; empty while off the skin.
    public var values: [Int] { offSkin ? [] : samples.filter { $0 != Self.offSkinValue } }

    /// Median one-second peak-to-trough over the last few seconds, or nil while off the skin or
    /// before a full set of windows has arrived.
    public var pulseAmplitude: Int? {
        let need = Self.amplitudeWindows * Self.sampleHz
        guard samples.count >= need else { return nil }
        let recent = samples.suffix(need)
        guard !recent.contains(Self.offSkinValue) else { return nil }
        let ranges = stride(from: recent.startIndex, to: recent.endIndex, by: Self.sampleHz).map { start in
            let window = recent[start..<(start + Self.sampleHz)]
            return window.max()! - window.min()!
        }.sorted()
        return ranges[ranges.count / 2]
    }

    public mutating func add(_ batch: [PpgSample]) {
        samples.append(contentsOf: batch.map(\.value))
        if samples.count > Self.keepSamples { samples.removeFirst(samples.count - Self.keepSamples) }
    }
}
