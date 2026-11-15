import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Temperature in RecordingSession")
struct TemperatureSessionTests {
    static let warm = TemperatureReading(ambientDeci: 315, skinDeci: 329, bodyDeci: 365)
    static let warmer = TemperatureReading(ambientDeci: 314, skinDeci: 329, bodyDeci: 365)

    private func rows(_ rig: TestRig) throws -> [[Int64]] {
        try rig.database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT recording_id, received_at_ms, ambient_deci, skin_deci, body_deci FROM temperature ORDER BY received_at_ms")
                .map { [$0[0], $0[1], $0[2], $0[3], $0[4]] }
        }
    }

    /// One report a second, as the band sends them.
    private func reports(_ r: TemperatureReading, seconds: Int) -> [FakeHeartSource.Step] {
        (0..<seconds).flatMap { _ in [.emit(.temperature(r)), .wait(ms: 1000)] }
    }

    @Test("written only while recording, on change or once a minute")
    func thinned() async throws {
        let rig = try TestRig()
        try await rig.play(reports(Self.warm, seconds: 3))
        #expect(try rig.count("temperature") == 0, "idle reports are not stored")

        let id = try await rig.session.start(name: "breath")
        let t0 = rig.clock.nowMs()
        try await rig.play(reports(Self.warm, seconds: 70) + reports(Self.warmer, seconds: 2))
        let r = try rows(rig)
        #expect(r.map { $0[1] - t0 } == [0, 60_000, 70_000], "first, the minute heartbeat, then the change")
        #expect(r.allSatisfy { $0[0] == id })
        #expect(r.last?[2...] == [314, 329, 365])
    }

    @Test("a new recording starts with a row even if the values have not changed")
    func freshPerRecording() async throws {
        let rig = try TestRig()
        try await rig.session.start(name: "a")
        try await rig.play(reports(Self.warm, seconds: 2))
        try await rig.session.stop()
        try await rig.session.start(name: "b")
        try await rig.play(reports(Self.warm, seconds: 2))
        #expect(try rig.count("temperature") == 2)
    }
}
