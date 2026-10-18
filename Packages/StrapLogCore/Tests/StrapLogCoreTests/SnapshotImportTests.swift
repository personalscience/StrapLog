import Foundation
import GRDB
import Synchronization
import Testing
@testable import StrapLogCore

@Suite("SnapshotImport")
struct SnapshotImportTests {
    private static let startMs: Int64 = 1_760_450_400_000

    /// A finished recording on a file database, snapshotted on stop into `dir/export`.
    private func recordAndStop(in dir: URL, name: String = "Ravine walk",
                               startMs: Int64 = startMs) async throws -> (TestRig, Recording, URL) {
        let rig = try TestRig(database: .live(at: dir.appendingPathComponent("live-\(UUID())/live.sqlite")),
                              clock: FakeClock(startMs: startMs, tzOffsetS: -7 * 3600))
        try await rig.session.start(.sleep, name: name)
        try await rig.play([
            .emit(.connected(deviceId: "H10", firmware: "5.0")),
            .wait(ms: 1000), hr([1000]), .wait(ms: 1000), hr([700, 720]),
        ])
        try await rig.session.marker(label: "a")
        let out = dir.appendingPathComponent("export")
        let rec = try await rig.session.stop(snapshotInto: out)
        return (rig, rec, out.appendingPathComponent(Snapshot.fileName(for: rec)))
    }

    // Synchronous, so async tests get GRDB's blocking `read` rather than its async overload.
    private func read<T>(_ db: StrapLogDatabase, _ body: (Database) throws -> T) throws -> T {
        try db.writer.read(body)
    }

    private func execute(_ file: URL, _ sql: String) throws {
        let queue = try DatabaseQueue(path: file.path)
        try queue.write { try $0.execute(sql: sql) }
        try queue.close()
    }

    private func rows(_ db: StrapLogDatabase, _ sql: String) throws -> [Row] {
        try read(db) { try Row.fetchAll($0, sql: sql) }
    }

    @Test("a reinstalled app gets the recording back, row for row")
    func reinstall() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (rig, rec, file) = try await recordAndStop(in: dir)
        let fresh = try StrapLogDatabase.inMemory()

        let ids = try SnapshotImport.run(fresh, folders: [file.deletingLastPathComponent()])

        #expect(ids == [rec.id!])
        let copy = try read(fresh) { try Recording.fetchOne($0, key: rec.id!) }
        #expect(copy == rec)
        for table in ["notification", "beat", "event", "motion"] {
            let sql = "SELECT * FROM \(table) ORDER BY 1, 2"
            #expect(try rows(fresh, sql) == rows(rig.database, sql), "\(table)")
        }
        let summary = { (db: StrapLogDatabase) in try read(db) { try RecordingSummary.all($0) } }
        #expect(try summary(fresh) == summary(rig.database))
    }

    @Test("ids taken in the live database are remapped, children follow")
    func idClash() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (rig, rec, file) = try await recordAndStop(in: dir)
        // The reinstalled app has already recorded something under the same ids.
        let fresh = try TestRig(database: .inMemory(), clock: FakeClock(startMs: Self.startMs + 86_400_000))
        try await fresh.session.start(name: "new")
        try await fresh.play([hr([900, 910, 920])])
        try await fresh.session.stop()

        let ids = try SnapshotImport.run(fresh.database, folders: [file.deletingLastPathComponent()])

        let newId = try #require(ids.first)
        #expect(newId != rec.id)
        #expect(try fresh.recording(newId)?.name == rec.name)
        #expect(try fresh.beats().filter { $0.recordingId == newId }.map(\.rr1024) == rig.beats().map(\.rr1024))
        #expect(try fresh.kinds(newId) == rig.kinds(rec.id!))
        #expect(try rows(fresh.database, "PRAGMA foreign_key_check").isEmpty)
        let orphans = try rows(fresh.database, """
            SELECT 1 FROM beat b JOIN notification n ON n.id = b.notification_id WHERE b.recording_id != n.recording_id
            """)
        #expect(orphans.isEmpty)
    }

    @Test("a second run imports nothing and leaves imported names out of the candidates")
    func idempotent() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, _, file) = try await recordAndStop(in: dir)
        let folder = file.deletingLastPathComponent()
        let fresh = try StrapLogDatabase.inMemory()

        #expect(try SnapshotImport.run(fresh, folders: [folder]).count == 1)
        #expect(try SnapshotImport.run(fresh, folders: [folder]).isEmpty)
        let known = try read(fresh) { Set(try Recording.fetchAll($0).map(Snapshot.fileName(for:))) }
        #expect(SnapshotImport.candidates(in: [folder], known: known).files.isEmpty)
    }

    @Test("a renamed copy of a present recording is not imported twice")
    func duplicateByStart() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (rig, rec, file) = try await recordAndStop(in: dir)
        // Same start and strap, but the live recording was renamed since this file was written.
        try await rig.session.edit(rec.id!, RecordingEdit(name: "Renamed", activity: rec.activity))
        #expect(try SnapshotImport.run(rig.database, folders: [file.deletingLastPathComponent()]).isEmpty)
        #expect(try rig.count("recording") == 1)
    }

    @Test("a legacy v2 multi-recording export imports only the recording it is named for")
    func legacyMultiRecording() throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let named = Recording(name: "STRENGTH 261016", startedAtMs: Self.startMs + 3_600_000, tzOffsetS: -7 * 3600)
        let file = dir.appendingPathComponent(Snapshot.fileName(for: named))
        let legacy = try DatabaseQueue(path: file.path)
        try Schema.migrator.migrate(legacy, upTo: "v2")
        try legacy.write { db in
            for (id, name, start) in [(1, "DELETED TEST", Self.startMs), (9, named.name, named.startedAtMs)] {
                try db.execute(sql: """
                    INSERT INTO recording(id, name, started_at_ms, ended_at_ms, tz_offset_s, device_id)
                    VALUES (?, ?, ?, ?, -25200, 'H10')
                    """, arguments: [id, name, start, start + 60_000])
                try db.execute(sql: "INSERT INTO event(recording_id, at_ms, kind, note) VALUES (?, ?, 'marker', 'x')",
                               arguments: [id, start + 1000])
            }
        }
        try legacy.close()
        let fresh = try StrapLogDatabase.inMemory()

        #expect(try SnapshotImport.run(fresh, folders: [dir]) == [9])
        let rec = try fresh.writer.read { try Recording.fetchOne($0, key: 9) }
        #expect(rec?.name == named.name)
        #expect(rec?.activity == ActivityPreset.other.id)
        #expect(try rows(fresh, "SELECT note, label FROM event") == [["note": "x", "label": DatabaseValue.null]])
    }

    @Test("a snapshot taken mid-recording imports closed at its last activity")
    func openSnapshot() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rig = try TestRig(database: .live(at: dir.appendingPathComponent("live/live.sqlite")))
        let id = try await rig.session.start(name: "night")
        try await rig.play([.wait(ms: 1000), hr([1000]), .wait(ms: 5000), hr([990])])
        let lastHeard = try #require(rig.notifications().last?.receivedAtMs)
        let file = try await rig.session.snapshot(into: dir.appendingPathComponent("export"))
        let fresh = try TestRig(database: .inMemory())

        #expect(try SnapshotImport.run(fresh.database, folders: [file.deletingLastPathComponent()]) == [id])
        // The snapshot event is logged before the file is written, so it is the last activity.
        let snapshotAt = try #require(fresh.events(id).last { $0.kind == .snapshot }?.atMs)
        #expect(snapshotAt >= lastHeard)
        #expect(try fresh.recording(id)?.endedAtMs == snapshotAt)
        let stop = try #require(fresh.events(id).last)
        #expect(stop.kind == .stop)
        #expect(stop.note == SnapshotImport.importedNote)
        #expect(try await fresh.relaunched().resumeIfOpen() == nil)
    }

    @Test("evicted iCloud files are requested by their real name, not imported")
    func placeholder() throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let placeholder = dir.appendingPathComponent(".251014-0700-night.sqlite.icloud")
        try Data().write(to: placeholder)
        let requested = Mutex<[URL]>([])

        let ids = try SnapshotImport.run(try .inMemory(), folders: [dir]) { url in requested.withLock { $0.append(url) } }

        #expect(ids.isEmpty)
        #expect(requested.withLock { $0 } == [dir.appendingPathComponent("251014-0700-night.sqlite")])
    }

    @Test("the same file in iCloud and local imports once, the newer copy")
    func newestCopyWins() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, rec, file) = try await recordAndStop(in: dir)
        let local = dir.appendingPathComponent("local")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        let newer = local.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.copyItem(at: file, to: newer)
        try execute(newer, "UPDATE recording SET notes = 'newer'")
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: newer.path)
        let fresh = try StrapLogDatabase.inMemory()

        #expect(try SnapshotImport.run(fresh, folders: [file.deletingLastPathComponent(), local]) == [rec.id!])
        #expect(try read(fresh) { try Recording.fetchOne($0, key: rec.id!) }?.notes == "newer")
    }

    @Test("a corrupt or foreign file is skipped and the rest still import")
    func badFileSkipped() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, rec, file) = try await recordAndStop(in: dir)
        let folder = file.deletingLastPathComponent()
        try Data("not sqlite".utf8).write(to: folder.appendingPathComponent("000101-0000-garbage.sqlite"))
        try execute(folder.appendingPathComponent("000101-0001-foreign.sqlite"), "CREATE TABLE t(x)")

        #expect(try SnapshotImport.run(try .inMemory(), folders: [folder]) == [rec.id!])
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).allSatisfy {
            !$0.hasSuffix("-journal") && !$0.hasSuffix("-wal")
        })
    }

    @Test("coming to the foreground fills Home and the index from the export folder")
    @MainActor
    func modelImportsOnForeground() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let (_, rec, file) = try await recordAndStop(in: dir)
        let folder = file.deletingLastPathComponent()
        let model = RecorderModel(database: try .inMemory(), exports: ExportFolder(local: folder),
                                  defaults: UserDefaults(suiteName: "SnapshotImportTests-\(UUID())")!)
        await model.launch()
        #expect(model.recordings.isEmpty)

        await model.appPhase(.foreground)

        #expect(model.errorMessage == nil)
        #expect(model.recordings.map(\.id) == [rec.id!])
        let index = try JSONDecoder().decode(ExportIndex.self,
                                             from: Data(contentsOf: folder.appendingPathComponent(ExportIndex.fileName)))
        #expect(index.recordings.map(\.file) == [file.lastPathComponent])
    }
}
