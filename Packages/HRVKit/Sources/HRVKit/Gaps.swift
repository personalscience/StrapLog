/// Holes in a run of sample times: gaps, counting the window edges, longer than
/// `RSADefaults.maxHoleSeconds`.
enum Gaps {
    /// Longest gap between `fromS`, the sorted times, and `toS`.
    static func longest(_ sortedT: [Double], fromS: Double, toS: Double) -> Double {
        gaps(sortedT, fromS: fromS, toS: toS).max() ?? 0
    }

    /// Total length of the gaps that count as holes.
    static func holeSeconds(_ sortedT: [Double], fromS: Double, toS: Double) -> Double {
        gaps(sortedT, fromS: fromS, toS: toS).filter { $0 > RSADefaults.maxHoleSeconds }.reduce(0, +)
    }

    private static func gaps(_ sortedT: [Double], fromS: Double, toS: Double) -> [Double] {
        let edges = [fromS] + sortedT + [toS]
        return zip(edges, edges.dropFirst()).map { $1 - $0 }
    }
}
