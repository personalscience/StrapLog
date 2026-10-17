import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("ExportIndex")
struct ExportIndexTests {
    private func read(_ directory: URL) throws -> ExportIndex {
        try JSONDecoder().decode(ExportIndex.self, from: Data(contentsOf: directory.appendingPathComponent(ExportIndex.fileName)))
    }

    @Test("each export rewrites index.json: newest first, with activity, times, beats, coverage and labels")
    func rewrittenOnExport() async throws {
        let dir = try scratchDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let rig = try TestRig(clock: FakeClock(startMs: 1_760_450_400_000, tzOffsetS: -7 * 3600))
        try await rig.session.start(name: "walk")
        try await rig.play([hr([1000]), .wait(ms: 1000), hr([1000]), .wait(ms: 10_000), hr([1000])])
        try await rig.session.marker(label: "a")
        try await rig.session.marker(note: "free text only")
        let walk = try await rig.session.stop(snapshotInto: dir)
        #expect(try read(dir).recordings.map(\.name) == ["walk"])

        rig.clock.advance(byMs: 3_600_000)
        try await rig.session.start(.sleep, name: "")
        try await rig.session.snapshot(into: dir)
        let index = try read(dir)

        #expect(index.format == "straplog-index")
        #expect(index.version == 1)
        #expect(index.appVersion == "dev")
        #expect(index.generatedAtMs == rig.clock.nowMs())
        #expect(index.recordings.map(\.activity) == ["sleep", "other"])
        let night = index.recordings[0]
        #expect(night.endedAtMs == nil)
        #expect(night.durationMs == nil)
        let entry = index.recordings[1]
        #expect(entry.file == Snapshot.fileName(for: walk))
        #expect(entry.id == walk.id)
        #expect(entry.startedAtMs == 1_760_450_400_000)
        #expect(entry.endedAtMs == walk.endedAtMs)
        #expect(entry.durationMs == walk.endedAtMs! - walk.startedAtMs)
        #expect(entry.tzOffsetS == -7 * 3600)
        #expect(entry.startedLocal == "2025-10-14T07:00:00-07:00")
        #expect(entry.beats == 3)
        #expect(entry.coverage == 0.0909, "10 s gap in an 11 s span")
        #expect(entry.labels == ["a"])
    }

    @Test("only recordings with a file in the folder are listed; an evicted iCloud placeholder counts")
    func filesPresent() async throws {
        let rig = try TestRig()
        var recs: [Recording] = []
        for name in ["here", "evicted", "elsewhere"] {
            try await rig.session.start(name: name)
            recs.append(try await rig.session.stop())
            rig.clock.advance(byMs: 60_000)
        }
        let files: Set<String> = [Snapshot.fileName(for: recs[0]),
                                  ExportIndex.downloadedName(".\(Snapshot.fileName(for: recs[1])).icloud"),
                                  ExportIndex.fileName]
        let index = try await rig.database.writer.read { db in
            try ExportIndex.build(db, files: files, appVersion: "1.0 (1)", generatedAtMs: 0)
        }
        #expect(index.recordings.map(\.name) == ["evicted", "here"])
        #expect(ExportIndex.downloadedName("x.sqlite") == "x.sqlite")
    }

    @Test("a missing folder is left alone")
    func missingFolder() async throws {
        let rig = try TestRig()
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try await rig.session.reindex(missing)
        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }
}
