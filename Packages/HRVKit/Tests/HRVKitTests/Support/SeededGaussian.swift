import Foundation

/// Deterministic standard-normal generator (SplitMix64 + Box–Muller) so synthetic
/// tests are reproducible across runs and machines.
struct SeededGaussian {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Double {
        let u1 = max(uniform(), .leastNonzeroMagnitude), u2 = uniform()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    mutating func series(_ n: Int) -> [Double] { (0..<n).map { _ in next() } }

    private mutating func uniform() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}
