/// Running Pearson correlation of paired values.
struct Correlation: Sendable {
    private(set) var n = 0
    private var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0

    init() {}

    init<S: Sequence>(_ pairs: S) where S.Element == (Double, Double) {
        for (x, y) in pairs { add(x, y) }
    }

    mutating func add(_ x: Double, _ y: Double) {
        n += 1
        sx += x; sy += y
        sxx += x * x; syy += y * y; sxy += x * y
    }

    /// -1 to 1; nil with fewer than 3 pairs or a constant side.
    var r: Double? {
        let k = Double(n)
        let vx = k * sxx - sx * sx, vy = k * syy - sy * sy
        guard n >= 3, vx > 0, vy > 0 else { return nil }
        return (k * sxy - sx * sy) / (vx * vy).squareRoot()
    }
}
