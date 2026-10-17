import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("Snapshot")
struct SnapshotTests {
    /// A WAL file database with one finished recording, snapshotted on stop.
    private func recordAndStop(in dir: URL) async throws -> (TestRig, Recording, URL) {
        let rig = try TestRig(database: .live(at: dir.appendingPathComponent("live/live.sqlite")),
                              clock: FakeClock(startMs: 1_760_450_400_000, tzOffsetS: -7 * 3600))
        try await rig.session.start(name: "Ravine walk")
        try await rig.play([
            .emit(.connected(deviceId: "H10", firmware: "5.0")),
            .wait(ms: 1000), hr([1000]), .wait(ms: 1000), hr([700, 720]),
        ])
        try await rig.session.marker(label: "a")
        let out = dir.appendingPathComponent("export")
        let rec = try await rig.session.stop(snapshotInto: out)
        return (rig, rec, out.appendingPathComponent(Snapshot.fileName(for: rec)))
    }

    private func sqlite3(_ file: URL, _ sql: String) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        p.arguments = [file.path, sql]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        #expect(p.terminationStatus == 0)
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("file name is local start time plus sanitised name")
    func fileName() {
        var rec = Recording(name: "Ravine walk/2", startedAtMs: 1_760_450_400_000, tzOffsetS: -7 * 3600)
        // 2025-10-14 14:00 UTC → 07:00 at UTC−7
        #expect(Snapshot.fileName(for: rec) == "251014-0700-Ravine_walk_2.sqlite")
        rec.name = ""
        #expect(Snapshot.fileName(for: rec) == "251014-0700.sqlite")
    }

    @Test("stop snapshot opens with plain sqlite3, has equal row counts, leaves no sidecars")
    func stopSnapshot() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (rig, rec, file) = try await recordAndStop(in: dir)

        for table in ["recording", "notification", "beat", "event", "meta"] {
            #expect(try sqlite3(file, "SELECT COUNT(*) FROM \(table)") == String(try rig.count(table)), "\(table)")
        }
        #expect(try sqlite3(file, "PRAGMA journal_mode") == "delete")
        #expect(try sqlite3(file, "SELECT kind FROM event ORDER BY id") .split(separator: "\n")
                == ["start", "connect", "marker", "stop", "snapshot"])
        #expect(try sqlite3(file, "SELECT ended_at_ms FROM recording") == String(rec.endedAtMs!))

        let exported = try FileManager.default.contentsOfDirectory(atPath: file.deletingLastPathComponent().path)
        #expect(exported == [file.lastPathComponent])

        let copy = try DatabaseQueue(path: file.path)
        #expect(try DBInvariants.violations(copy).isEmpty)
    }

    @Test("a snapshot holds only its own recording, with its original id")
    func oneRecordingPerFile() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (rig, first, firstFile) = try await recordAndStop(in: dir)
        rig.clock.advance(byMs: 60_000)
        try await rig.session.start(name: "second")
        try await rig.play([.wait(ms: 1000), hr([900, 950, 1000])])
        let second = try await rig.session.stop(snapshotInto: dir.appendingPathComponent("export"))
        let secondFile = firstFile.deletingLastPathComponent().appendingPathComponent(Snapshot.fileName(for: second))

        #expect(try sqlite3(firstFile, "SELECT id FROM recording") == String(first.id!))
        #expect(try sqlite3(secondFile, "SELECT id FROM recording") == String(second.id!))
        #expect(try sqlite3(secondFile, "SELECT COUNT(*) FROM beat") == "3")
        for table in ["notification", "beat", "event"] {
            #expect(try sqlite3(secondFile, "SELECT COUNT(*) FROM \(table) WHERE recording_id != \(second.id!)") == "0",
                    "\(table)")
        }
        #expect(try sqlite3(secondFile, "SELECT COUNT(*) FROM meta") == "2")
    }

    @Test("periodic snapshot overwrites the same file and logs an event each time")
    func periodicOverwrite() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rig = try TestRig(database: .live(at: dir.appendingPathComponent("live.sqlite")))
        let id = try await rig.session.start(name: "night")
        let out = dir.appendingPathComponent("export")

        try await rig.play([hr([1000])])
        let first = try await rig.session.snapshot(into: out)
        rig.clock.advance(byMs: 30 * 60_000)
        try await rig.play([hr([1000]), hr([1000])])
        let second = try await rig.session.snapshot(into: out)

        #expect(first == second)
        #expect(try sqlite3(second, "SELECT COUNT(*) FROM notification") == "3")
        #expect(try rig.kinds(id) == [.start, .snapshot, .snapshot])
        #expect(try FileManager.default.contentsOfDirectory(atPath: out.path) == [second.lastPathComponent])
    }

    @Test("snapshot while idle is refused")
    func idle() async throws {
        let rig = try TestRig()
        await #expect(throws: RecordingSessionError.notRecording) {
            try await rig.session.snapshot(into: FileManager.default.temporaryDirectory)
        }
    }
}
