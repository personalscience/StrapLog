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

    @Test("marker confirmation: note, seconds since, count")
    func marker() {
        #expect(Formats.marker(nil, count: 0, nowMs: 0) == "No markers yet")
        let e = RecordingEvent(recordingId: 1, atMs: 10_000, kind: .marker, note: "b")
        #expect(Formats.marker(e, count: 1, nowMs: 10_400) == "b · 0 s ago · 1 marker")
        #expect(Formats.marker(e, count: 5, nowMs: 22_000) == "b · 12 s ago · 5 markers")
    }

    @Test("live metric values, with -- when a window has none")
    func liveMetrics() {
        #expect(Formats.decimal(0.8234) == "0.82")
        #expect(Formats.decimal(nil) == "--")
        #expect(Formats.ms(42.06) == "42.1 ms")
        #expect(Formats.bpm(61.4) == "61 bpm")
        #expect(Formats.percent(0.0123) == "1.2 %")
        #expect(Formats.percent(nil) == "--")
        #expect(Formats.contact(false) == "No skin contact")
    }

    @Test("window status before, with and without features")
    func windowStatus() {
        #expect(Formats.window(endMs: nil, hasFeatures: false, nowMs: 0) == "First values after 2 min of beats")
        #expect(Formats.window(endMs: 10_000, hasFeatures: true, nowMs: 22_500) == "2-min window ending 12 s ago")
        #expect(Formats.window(endMs: 10_000, hasFeatures: false, nowMs: 10_000)
                == "Too few beats in the window ending 0 s ago")
    }

    @Test("pacer rate and countdown")
    func pacer() {
        #expect(Formats.rate(4.5) == "4.5 breaths / min")
        #expect(Formats.countdown(seconds: 5) == "5")
        #expect(Formats.countdown(seconds: 0.2) == "1")
    }
}
