/// Result of `RRCleaner.clean`: the surviving beats and which raw indices were dropped.
public struct RRCleaning: Sendable, Equatable {
    public let raw: [Double]
    /// Ascending indices into `raw` of beats removed by the gate or the median filter.
    public let removedIndices: [Int]

    public var kept: [Double] {
        let removed = Set(removedIndices)
        return raw.indices.filter { !removed.contains($0) }.map { raw[$0] }
    }

    public var artifactCount: Int { removedIndices.count }

    /// Fraction of raw beats removed; nil for empty input.
    public var artifactRate: Double? {
        raw.isEmpty ? nil : Double(artifactCount) / Double(raw.count)
    }
}
