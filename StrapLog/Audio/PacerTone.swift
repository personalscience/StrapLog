import Foundation

/// The pacer's tones as samples: a struck bell, a bright ping that fades across the whole half
/// of the breath, so the fade itself paces it. Inhale rings a fifth above exhale.
///
/// Synthesised as a few inharmonic partials, each with a 4 ms attack and its own exponential
/// decay: the strike partials die in a fraction of a second, the prime rings to the end. A
/// partial a few cents off the prime beats against it, the slow shimmer of a temple bell.
enum PacerTone {
    static let sampleRate = 22_050.0
    static let inhaleHz = 587.33
    static let exhaleHz = 392.0
    /// Peak sample value.
    static let amplitude = 0.3
    /// Shortest tone, whatever the half-breath.
    static let minimumSeconds = 0.5
    /// The prime has decayed by this much at the end of the tone.
    static let endDecayDb = -40.0

    private static let attack = 0.004
    /// The last stretch, faded to exact silence so a tone cut by the next one never clicks.
    private static let tail = 0.05

    /// Frequency ratio to the prime, relative level, and decay time as a share of the prime's.
    private static let partials: [(ratio: Double, level: Double, decay: Double)] = [
        (0.5, 0.25, 1.2),    // hum, an octave down
        (1.0, 1.0, 1.0),     // prime
        (1.004, 0.6, 1.0),   // beats against the prime
        (2.0, 0.45, 0.6),
        (2.76, 0.3, 0.4),
        (5.4, 0.2, 0.12),    // the bright ping
        (8.93, 0.1, 0.05),   // the strike
    ]

    static func frameCount(seconds: Double) -> Int {
        Int((max(minimumSeconds, seconds) * sampleRate).rounded())
    }

    /// One tone lasting `seconds` (at least `minimumSeconds`), peaking at `amplitude`, silent at both ends.
    static func samples(inhaling: Bool, seconds: Double) -> [Float] {
        let f0 = inhaling ? inhaleHz : exhaleHz
        let frames = frameCount(seconds: seconds)
        let length = Double(frames) / sampleRate
        let tau = length / (-endDecayDb / 20 * log(10))
        var raw = [Double](repeating: 0, count: frames)
        for (ratio, level, decay) in partials {
            let step = 2 * .pi * f0 * ratio / sampleRate
            let fall = exp(-1 / (sampleRate * tau * decay))
            var gain = level
            for i in 0..<frames {
                raw[i] += gain * sin(step * Double(i))
                gain *= fall
            }
        }
        let peak = raw.lazy.map(abs).max() ?? 0
        let scale = peak > 0 ? amplitude / peak : 0
        return raw.indices.map { i in
            let t = Double(i) / sampleRate
            return Float(raw[i] * scale * edge(t: t, length: length))
        }
    }

    /// 0 → 1 across the attack, 1 → 0 across the tail (raised cosine), 1 between.
    private static func edge(t: Double, length: Double) -> Double {
        if t < attack { return t / attack }
        let intoTail = t - (length - tail)
        guard intoTail > 0 else { return 1 }
        return (1 + cos(.pi * min(1, intoTail / tail))) / 2
    }
}
