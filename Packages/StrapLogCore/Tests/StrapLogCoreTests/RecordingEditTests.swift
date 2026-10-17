import Testing
@testable import StrapLogCore

@Suite("RecordingEdit")
struct RecordingEditTests {
    let recording: Recording = {
        var rec = Recording(name: "RAVINE", activity: "other", startedAtMs: 1_760_000_000_000, tzOffsetS: -7 * 3600)
        rec.notes = "felt good"
        return rec
    }()

    @Test("round-trips a recording's fields unchanged")
    func roundTrip() {
        #expect(RecordingEdit(recording).applied(to: recording) == recording)
    }

    @Test("trims; a blank name becomes the activity's default name, blank notes nil")
    func normalises() {
        let edited = RecordingEdit(name: "  ", activity: "sleep", notes: " \n ").applied(to: recording)
        #expect(edited.activity == "sleep")
        #expect(edited.name == ActivityPreset.sleep.defaultName(atMs: recording.startedAtMs, tzOffsetS: recording.tzOffsetS))
        #expect(edited.notes == nil)
        #expect(RecordingEdit(name: " ride ", activity: "other", notes: " ok ").applied(to: recording).name == "ride")
    }

    @Test("an unknown activity id becomes other")
    func unknownActivity() {
        #expect(RecordingEdit(name: "x", activity: "kayak").applied(to: recording).activity == "other")
    }
}
