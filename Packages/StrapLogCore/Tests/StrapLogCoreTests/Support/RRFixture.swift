import Foundation

/// The beat series of a repo-root `Tests/fixtures/<name>.json` (written by `tools/gen_fixtures.py`).
struct RRFixture: Decodable {
    let t_rel_s: [Double]
    let rr_ms: [Double]

    static let names = ["resting", "strength", "overnight"]

    static func url(_ name: String) -> URL {
        URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../../Tests/fixtures/\(name).json").standardized
    }

    static func load(_ name: String) throws -> RRFixture {
        try JSONDecoder().decode(RRFixture.self, from: Data(contentsOf: url(name)))
    }

    /// Beat end times in ms from `originMs`. The fixtures carry whole milliseconds, so this is exact.
    func endTimesMs(originMs: Int64 = 0) -> [Int64] {
        t_rel_s.map { originMs + Int64(($0 * 1000).rounded()) }
    }
}
