import Foundation
import GRDB
import Testing
@testable import StrapLogCore

@Suite("MarkerPresets")
struct MarkerPresetsTests {
    @Test("an edit replaces one activity's bar and leaves the rest of the preset alone")
    func edit() {
        var presets = MarkerPresets()
        presets.setMarkers(["warmup", " set ", "", "set", "cooldown"], for: "other")
        #expect(presets.preset("other").markers == ["warmup", "set", "cooldown"])
        #expect(presets.preset("other").pacer == ActivityPreset.other.pacer)
        #expect(presets.preset("sleep") == .sleep)
        #expect(presets.isEdited("other"))
        #expect(!presets.isEdited("sleep"))
    }

    @Test("setting the default bar or resetting drops the edit; unknown ids edit other")
    func defaults() {
        var presets = MarkerPresets()
        presets.setMarkers(["x"], for: "sleep")
        presets.setMarkers(ActivityPreset.sleep.markers, for: "sleep")
        #expect(!presets.isEdited("sleep"))
        presets.setMarkers(["x"], for: "ruck-from-a-newer-build")
        #expect(presets.preset("other").markers == ["x"])
        presets.reset("other")
        #expect(presets == MarkerPresets())
    }

    @Test("an empty bar is a valid edit: only the free-text marker is left")
    func empty() {
        var presets = MarkerPresets()
        presets.setMarkers([" "], for: "other")
        #expect(presets.preset("other").markers.isEmpty)
    }

    @Test("round-trips through UserDefaults; a missing or corrupt key loads as no edits")
    func persistence() throws {
        let defaults = try #require(UserDefaults(suiteName: "MarkerPresetsTests-\(UUID().uuidString)"))
        #expect(MarkerPresets.load(from: defaults) == MarkerPresets())
        var presets = MarkerPresets()
        presets.setMarkers(["lights_out", "bathroom", "up"], for: "sleep")
        try presets.save(to: defaults)
        #expect(MarkerPresets.load(from: defaults) == presets)
        defaults.set(Data("not json".utf8), forKey: MarkerPresets.key)
        #expect(MarkerPresets.load(from: defaults) == MarkerPresets())
    }
}

@MainActor
@Suite("RecorderModel markers")
struct RecorderModelMarkerTests {
    let database: StrapLogDatabase
    let clock = FakeClock()
    let dir: URL
    let defaults: UserDefaults
    let model: RecorderModel

    init() throws {
        database = try .inMemory()
        dir = try scratchDirectory()
        defaults = try #require(UserDefaults(suiteName: "RecorderModelMarkerTests-\(UUID().uuidString)"))
        model = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
    }

    /// Synchronous on purpose: in async contexts GRDB's `read` resolves to its async overload.
    func exportedMarkers(_ url: URL) throws -> String? {
        try DatabaseQueue(path: url.path).read {
            try String.fetchOne($0, sql: "SELECT value ->> '$.markers' FROM meta WHERE key = 'preset'")
        }
    }

    @Test("an edited bar applies mid-recording, survives a relaunch and travels in the export")
    func editedBar() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await model.launch()
        await model.start(name: "gym")
        await model.setMarkers(["squat", "bench"], for: .other)
        #expect(model.activePreset.markers == ["squat", "bench"])
        #expect(await model.markIfRecording("squat") != .notRecording)
        #expect(model.lastMarker?.label == "squat", "an edited label is a label, not a note")

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
        #expect(relaunched.markerPresets.preset("other").markers == ["squat", "bench"])

        await model.stop()
        let url = try #require(model.lastSnapshot)
        #expect(try exportedMarkers(url) == #"["squat","bench"]"#)

        await model.resetMarkers(for: .other)
        #expect(model.markerPresets.preset("other") == .other)
        #expect(model.errorMessage == nil)
    }

    @Test("recent notes: distinct, most recently used first, across recordings, capped")
    func recentNotes() async throws {
        defer { try? FileManager.default.removeItem(at: dir) }
        await model.launch()
        #expect(model.recentNotes.isEmpty)
        await model.start(name: "one")
        for note in ["dizzy", "water", "dizzy"] { await model.marker(note: note) }
        await model.marker(label: "a")
        #expect(model.recentNotes == ["dizzy", "water"])
        await model.stop()

        await model.start(name: "two")
        for i in 0..<RecorderModel.recentNoteLimit { await model.marker(note: "n\(i)") }
        await model.stop()

        let relaunched = RecorderModel(database: database, exports: ExportFolder(local: dir), clock: clock, defaults: defaults)
        await relaunched.launch()
        #expect(relaunched.recentNotes.count == RecorderModel.recentNoteLimit)
        #expect(relaunched.recentNotes.first == "n\(RecorderModel.recentNoteLimit - 1)")
        #expect(!relaunched.recentNotes.contains("dizzy"))
    }
}
