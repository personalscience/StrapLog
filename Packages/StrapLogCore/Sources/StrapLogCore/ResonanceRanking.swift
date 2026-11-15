import HRVKit

/// The resonance finder's answer (straplog-9fr.7): a recording's pacer rates ranked by how far
/// heart rate swung with the breath, largest first. The best rate is the one with the largest
/// swing alone (Rik, 2026-11-15); sync is carried for display, not used to rank. Runs at the
/// same rate pool their fitted windows, so a rate's swing is the median over all of them.
public struct ResonanceRanking: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        /// Breaths a minute.
        public let rate: Double
        /// Median fitted swing over the rate's windows (bpm).
        public let swing: Double
        /// Median sync over the same windows, 0–1.
        public let sync: Double
        /// Fitted windows behind the medians.
        public let windows: Int
    }

    /// Largest swing first; ties go to the faster rate.
    public let entries: [Entry]

    /// The rate with the largest swing.
    public var best: Entry { entries[0] }

    /// Nil unless at least two rates have a fitted window: one rate ranks nothing.
    public init?(_ summaries: [RSASummary]) {
        var fits: [Double: [CosinorFit]] = [:]
        for s in summaries { fits[s.run.stamp.breathsPerMinute, default: []] += s.block.fits }
        let entries = fits.compactMap { rate, fits -> Entry? in
            guard let swing = RSABlock.median(fits.map(\.swing)),
                  let sync = RSABlock.median(fits.map(\.sync)) else { return nil }
            return Entry(rate: rate, swing: swing, sync: sync, windows: fits.count)
        }
        guard entries.count >= 2 else { return nil }
        self.entries = entries.sorted { ($0.swing, $0.rate) > ($1.swing, $1.rate) }
    }
}
