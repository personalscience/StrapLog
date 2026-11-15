/// Decides which temperature reports are worth a row. The armband repeats the same values every
/// second and changes them about once a minute, so a row is kept when any value changes or
/// `heartbeatMs` has passed since the last kept row, which keeps a flat stretch visible as data
/// rather than a gap.
struct TemperatureThinner: Sendable {
    static let heartbeatMs: Int64 = 60_000

    private var last: (reading: TemperatureReading, atMs: Int64)?

    mutating func keep(_ reading: TemperatureReading, atMs: Int64) -> Bool {
        if let last, last.reading == reading, atMs - last.atMs < Self.heartbeatMs { return false }
        last = (reading, atMs)
        return true
    }
}
