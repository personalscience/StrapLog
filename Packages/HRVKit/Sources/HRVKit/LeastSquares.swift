/// Ordinary least squares by the normal equations, for the few-column fits RSA needs.
enum LeastSquares {
    /// β minimising ‖Xβ − y‖² for row-major `x`; nil when `XᵀX` is singular.
    static func solve(_ x: [[Double]], _ y: [Double]) -> [Double]? {
        guard let p = x.first?.count, x.count >= p else { return nil }
        var m = [[Double]](repeating: [Double](repeating: 0, count: p + 1), count: p)
        for (row, yi) in zip(x, y) {
            for i in 0..<p {
                for j in 0..<p { m[i][j] += row[i] * row[j] }
                m[i][p] += row[i] * yi
            }
        }
        // Gauss–Jordan with partial pivoting on the augmented p×(p+1) matrix.
        for col in 0..<p {
            let pivot = (col..<p).max { abs(m[$0][col]) < abs(m[$1][col]) }!
            guard abs(m[pivot][col]) > 1e-12 * max(1, abs(m[col][col])) else { return nil }
            m.swapAt(col, pivot)
            for r in 0..<p where r != col {
                let f = m[r][col] / m[col][col]
                for c in col...p { m[r][c] -= f * m[col][c] }
            }
        }
        return (0..<p).map { m[$0][p] / m[$0][$0] }
    }

    static func residualSquares(_ x: [[Double]], _ y: [Double], _ beta: [Double]) -> Double {
        zip(x, y).reduce(0) { sum, pair in
            let r = pair.1 - zip(pair.0, beta).reduce(0) { $0 + $1.0 * $1.1 }
            return sum + r * r
        }
    }
}
