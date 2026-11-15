/// Max − min HR inside one pacer breath, `startS ≤ t < endS`. No swing (a gap on the
/// screen, never zero) with fewer than `minBeatsPerBreath` samples or a hole.
public struct BreathSwing: Sendable, Equatable {
    public let startS: Double
    public let endS: Double
    /// Peak-to-trough HR (bpm), or nil when the breath is not measurable.
    public let swing: Double?
    /// HR samples inside the breath.
    public let beats: Int

    public init(_ samples: some Collection<TimedSample<Double>>, startS: Double, endS: Double) {
        let inside = samples.filter { startS <= $0.t && $0.t < endS }.sorted { $0.t < $1.t }
        let hr = inside.map(\.value)
        let measurable = hr.count >= RSADefaults.minBeatsPerBreath
            && Gaps.longest(inside.map(\.t), fromS: startS, toS: endS) <= RSADefaults.maxHoleSeconds
        self.startS = startS
        self.endS = endS
        self.beats = hr.count
        self.swing = measurable ? hr.max()! - hr.min()! : nil
    }
}
