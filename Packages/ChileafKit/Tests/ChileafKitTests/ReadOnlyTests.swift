import Foundation
import Testing

/// The band's command characteristic accepts shutdown and factory reset (Chileaf's SDK), so the
/// app must never write to it. The CoreBluetooth source is the only code that could, and it is
/// in the app target, outside any package; this reads its source text.
@Suite("Read-only toward the band")
struct ReadOnlyTests {
    static let source = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "ArmLog/Armband/ArmbandHeartSource.swift")

    @Test("ArmbandHeartSource never calls writeValue")
    func noWrites() throws {
        let text = try String(contentsOf: Self.source, encoding: .utf8)
        #expect(text.contains("CBPeripheralDelegate"), "found the right file")
        #expect(!text.contains("writeValue("))
        #expect(!text.contains("commandDoNotWrite)"), "not even turned into a CBUUID")
    }
}
