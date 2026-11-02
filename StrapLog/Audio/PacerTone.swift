import Foundation

/// The pacer's two tones as samples: a sweep up to breathe in, down to breathe out.
enum PacerTone {
    static let sampleRate = 44_100.0
    static let lowHz = 392.0
    static let highHz = 587.0
    static let duration = 0.35
    static let amplitude = 0.3

    static func samples(inhaling: Bool) -> [Float] {
        inhaling ? sweep(fromHz: lowHz, toHz: highHz) : sweep(fromHz: highHz, toHz: lowHz)
    }

    /// A sine sweep with a 20 ms attack and a raised-cosine decay to silence, so neither end clicks.
    private static func sweep(fromHz: Double, toHz: Double) -> [Float] {
        let attack = 0.02
        var phase = 0.0
        return (0..<Int(duration * sampleRate)).map { i in
            let t = Double(i) / sampleRate
            let envelope = t < attack ? t / attack : (1 + cos(.pi * (t - attack) / (duration - attack))) / 2
            let hz = fromHz + (toHz - fromHz) * t / duration
            defer { phase += 2 * .pi * hz / sampleRate }
            return Float(amplitude * envelope * sin(phase))
        }
    }
}
