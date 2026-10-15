import StrapLogCore
import Testing
@testable import StrapLog

@Suite("Formats")
struct FormatsTests {
    @Test("elapsed: M:SS under an hour, H:MM:SS above, never negative")
    func elapsed() {
        #expect(Formats.elapsed(ms: 0) == "0:00")
        #expect(Formats.elapsed(ms: 61_999) == "1:01")
        #expect(Formats.elapsed(ms: 3_600_000 + 5_000) == "1:00:05")
        #expect(Formats.elapsed(ms: -5_000) == "0:00")
    }

    @Test("gap in seconds with one decimal")
    func gap() {
        #expect(Formats.gap(ms: 4_000) == "4.0 s")
        #expect(Formats.gap(ms: 12_340) == "12.3 s")
    }

    @Test("start time uses the recording's own time zone")
    func started() {
        // 2025-10-09T08:53:20Z at UTC−7 → Oct 9, 01:53
        let s = RecordingSummary(id: 1, name: "x", startedAtMs: 1_760_000_000_000, endedAtMs: 1_760_000_600_000,
                                 tzOffsetS: -7 * 3600, beatCount: 3)
        #expect(Formats.started(s) == "Oct 9, 01:53")
        #expect(Formats.duration(s) == "10:00")
    }

    @Test("open recordings show 'open'")
    func open() {
        let s = RecordingSummary(id: 1, name: "x", startedAtMs: 0, endedAtMs: nil, tzOffsetS: 0, beatCount: 0)
        #expect(Formats.duration(s) == "open")
    }
}
