import Foundation

/// RSA over one stretch of paced breathing, after the fact: every whole breath of the pacer in
/// `[fromS, toS)`, its `BreathSwing`, and a cosinor over each run of `RSADefaults.windowBreaths`
/// whole breaths (stride one breath), the windows the live tracker fits. The block's numbers are
/// the medians over those windows, and the circular mean of their peaks. Mirrors `rsa.block` in
/// straplog-py and the `windows` of `tools/gen_rsa_fixture.py`.
public struct RSABlock: Sendable, Equatable {
    /// Every whole breath in the block, oldest first.
    public let breaths: [BreathSwing]
    /// The windows that fitted; a window failing `Cosinor.fit`'s gates is left out.
    public let fits: [CosinorFit]
    /// Windows tried (fitted or not).
    public let windows: Int

    /// `samples` are instant HR (`InstantHR`); breath `k` starts at `originS + k·periodS`.
    public init(_ samples: [TimedSample<Double>], periodS: Double, originS: Double, fromS: Double, toS: Double) {
        precondition(periodS > 0, "a breath has a length")
        let first = Int(((fromS - originS) / periodS - Self.slack).rounded(.up))
        let last = Int(((toS - originS) / periodS + Self.slack).rounded(.down))
        let bounds = first <= last ? (first...last).map { originS + Double($0) * periodS } : []
        breaths = zip(bounds, bounds.dropFirst()).map { BreathSwing(samples, startS: $0, endS: $1) }
        let starts = bounds.dropLast(RSADefaults.windowBreaths)
        windows = starts.count
        fits = starts.compactMap { Cosinor.fit(samples, periodS: periodS, fromS: $0) }
    }

    /// Breaths with a swing (enough beats, no hole).
    public var validBreaths: Int { breaths.filter { $0.swing != nil }.count }

    /// Median fitted swing (bpm); nil with no fit.
    public var swing: Double? { Self.median(fits.map(\.swing)) }

    /// Median sync, 0–1; nil with no fit.
    public var sync: Double? { Self.median(fits.map(\.sync)) }

    /// Circular mean of the fits' peak fractions, in [0, 1): a median would split peaks that sit
    /// either side of the breath boundary (0.97 and 0.03). Nil with no fit.
    public var peakFraction: Double? {
        guard !fits.isEmpty else { return nil }
        let x = fits.reduce(0) { $0 + cos(2 * .pi * $1.peakFraction) }
        let y = fits.reduce(0) { $0 + sin(2 * .pi * $1.peakFraction) }
        let f = atan2(y, x) / (2 * .pi)
        return f - f.rounded(.down)
    }

    /// Float slack when a boundary lands exactly on `fromS` or `toS`.
    static let slack = 1e-9

    public static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted(), m = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[m - 1] + s[m]) / 2 : s[m]
    }
}
