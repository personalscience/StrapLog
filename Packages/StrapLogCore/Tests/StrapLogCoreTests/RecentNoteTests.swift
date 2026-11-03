import Testing
@testable import StrapLogCore

@Suite("RecentNote")
struct RecentNoteTests {
    private func note(_ text: String, _ activities: String...) -> RecentNote {
        RecentNote(text: text, activities: Set(activities))
    }

    @Test("a query matches the start of any word, ignoring case and accents")
    func wordPrefix() {
        let notes = [note("Should Not"), note("Shoulder Press 110"), note("Shoulder Press 130"), note("Café"), note("Dizzy")]
        #expect(RecentNote.suggestions(notes, matching: "shou", activity: "") == ["Should Not", "Shoulder Press 110", "Shoulder Press 130"])
        #expect(RecentNote.suggestions(notes, matching: "press 13", activity: "") == ["Shoulder Press 130"])
        #expect(RecentNote.suggestions(notes, matching: "cafe", activity: "") == ["Café"])
        #expect(RecentNote.suggestions(notes, matching: "houlder", activity: "").isEmpty)
    }

    @Test("notes starting with the query beat word matches; then the activity; then recency")
    func ranking() {
        let notes = [note("Overhead Press", "other"), note("Press 100", "sleep"), note("Press 90", "other"), note("Water", "other")]
        #expect(RecentNote.suggestions(notes, matching: "press", activity: "other") == ["Press 90", "Press 100", "Overhead Press"])
        #expect(RecentNote.suggestions(notes, matching: "  ", activity: "sleep") == ["Press 100", "Overhead Press", "Press 90", "Water"])
    }

    @Test("case variants merge under the latest spelling and keep every activity")
    func merge() {
        let merged = RecentNote.merged([(text: "Dizzy", activity: "other"), (text: "water", activity: "other"),
                                        (text: "dizzy", activity: "sleep")], limit: 100)
        #expect(merged == [note("Dizzy", "other", "sleep"), note("water", "other")])
        #expect(RecentNote.merged([(text: "a", activity: "x"), (text: "b", activity: "x")], limit: 1).map(\.text) == ["a"])
    }
}

@Suite("MarkConfirmation")
struct MarkConfirmationTests {
    private func status(_ count: Int) -> LiveStatus {
        LiveStatus(name: "n", activity: "other", startedAtMs: 0, heartRate: nil, contact: nil, linked: true,
                   alpha1: nil, rmssd: nil, battery: nil, markers: [], markerCount: count)
    }

    @Test("confirms a sent marker once it lands, and only then")
    func landing() {
        var confirmation = MarkConfirmation()
        let phoneOnly = confirmation.landed(status(1))
        confirmation.sent(markerCount: 1)
        let notYet = confirmation.landed(status(1))
        let landed = confirmation.landed(status(2))
        let nothingOutstanding = confirmation.landed(status(3))
        #expect([phoneOnly, notYet, landed, nothingOutstanding] == [false, false, true, false])
    }

    @Test("two quick taps confirm separately; idle clears what is outstanding")
    func repeats() {
        var confirmation = MarkConfirmation()
        confirmation.sent(markerCount: 0)
        confirmation.sent(markerCount: 0)
        let taps = [confirmation.landed(status(1)), confirmation.landed(status(2)), confirmation.landed(status(3))]
        #expect(taps == [true, true, false])
        confirmation.sent(markerCount: 3)
        let idle = confirmation.landed(nil)
        let afterIdle = confirmation.landed(status(9))
        #expect([idle, afterIdle] == [false, false])
    }
}
