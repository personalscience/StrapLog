/// One raw accelerometer sample from a vendor frame, in the band's counts.
public struct AccelCounts: Sendable, Equatable {
    /// Counts per g. Inferred from one seated capture (|v| ≈ 0.96 g at rest, 2026-11-03), not
    /// from Chileaf's documentation: treat milli-g values derived from it as approximate.
    public static let countsPerG = 4096

    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int, y: Int, z: Int) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// The sample in milli-g, the unit StrapLog's motion pipeline uses.
    public var milliG: (x: Int, y: Int, z: Int) {
        (x * 1000 / Self.countsPerG, y * 1000 / Self.countsPerG, z * 1000 / Self.countsPerG)
    }
}
