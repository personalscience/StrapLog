import Foundation
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

    @Test("overnight plan line: wake time in local time, then the upright rule")
    func overnightPlan() {
        let pdt = TimeZone(secondsFromGMT: -7 * 3600)!
        #expect(Formats.overnightPlan(OvernightPlan(wakeAtMs: 1_760_621_400_000), timeZone: pdt)
                == "5 min resting at 06:30, then stops; or after 10 min upright")
        #expect(Formats.overnightPlan(OvernightPlan(wakeAtMs: nil)) == "Stops after 10 min upright")
    }

    @Test("start time uses the recording's own time zone")
    func started() {
        // 2025-10-09T08:53:20Z at UTC−7 → Oct 9, 01:53
        let s = RecordingSummary(id: 1, name: "x", startedAtMs: 1_760_000_000_000, endedAtMs: 1_760_000_600_000,
                                 tzOffsetS: -7 * 3600, beatCount: 3)
        #expect(Formats.started(s) == "Oct 9, 01:53")
        #expect(Formats.duration(s) == "10:00")
    }

    @Test("overnight line: lowest HR and whole minutes recorded")
    func overnightLow() {
        #expect(Formats.overnightLow(lowestHR: 46.4, elapsedMs: 18_779_000) == "Low 46 · 5 h 12 min")
        #expect(Formats.overnightLow(lowestHR: nil, elapsedMs: 179_999) == "Low -- · 2 min")
    }

    @Test("summary strings: duration or open, clock in the recording's zone, minutes as h/min")
    func summaryStrings() {
        #expect(Formats.duration(ms: 28_812_000) == "8:00:12")
        #expect(Formats.duration(ms: nil) == "open")
        #expect(Formats.clock(atMs: 1_760_000_000_000, tzOffsetS: -7 * 3600) == "01:53:20")
        #expect(Formats.minutes(44.6) == "45 min")
        #expect(Formats.minutes(425) == "7 h 05 min")
        #expect(Formats.batteryRange(start: 82, end: 79) == "82 % → 79 %")
        #expect(Formats.batteryRange(start: 82, end: 82) == "82 %")
        #expect(Formats.batteryRange(start: nil, end: nil) == "--")
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
        let labelled = RecordingEvent(recordingId: 1, atMs: 10_000, kind: .marker, label: "awake", note: "bathroom")
        #expect(Formats.marker(labelled, count: 2, nowMs: 10_000) == "awake · bathroom · 0 s ago · 2 markers")
        #expect(Formats.markerButton("lights_out") == "lights out")
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

    @Test("hero subline and freshness")
    func heroSubline() {
        #expect(Formats.ago(ms: 12_500) == "12 s ago")
        #expect(Formats.ago(ms: 185_000) == "3 min ago")
        #expect(Formats.ago(ms: -1) == "0 s ago")
        #expect(Formats.heroSubline(rmssd: 8.12, artifactRate: 0.004, alpha1AtMs: nil, nowMs: 0)
                == "First α1 after 2 min of beats")
        #expect(Formats.heroSubline(rmssd: 8.12, artifactRate: 0.004, alpha1AtMs: 10_000, nowMs: 22_000)
                == "RMSSD 8.1 ms · artifacts 0.4 % · α1 12 s ago")
        #expect(Formats.heroSubline(rmssd: nil, artifactRate: nil, alpha1AtMs: 0, nowMs: 0)
                == "RMSSD -- · artifacts -- · α1 0 s ago")
    }

    @Test("toolbar title and device fields")
    func device() {
        #expect(Formats.recordingTitle(name: "RAVINE", elapsedMs: 761_000) == "12:41 · RAVINE")
        #expect(Formats.recordingTitle(name: "", elapsedMs: 5_000) == "0:05")
        #expect(Formats.battery(82) == "82 %")
        #expect(Formats.battery(nil) == "--")
        #expect(Formats.deviceId(.connected(deviceId: "A1B2C3D4")) == "A1B2C3D4")
        #expect(Formats.deviceId(.searching) == "--")
        #expect(Formats.text(nil) == "--")
    }

    @Test("chart span chip and tab labels")
    func chart() {
        #expect(ChartSpan.allCases.map(Formats.span) == ["1 min", "2 min", "5 min", "15 min", "30 min", "1 h", "All"])
        #expect(ChartMetric.allCases.map(Formats.metric) == ["HR", "α1", "RR"])
        #expect(Formats.axis(.rr) == "RR ms")
    }

    @Test("pacer rate and countdown")
    func pacer() {
        #expect(Formats.rate(4.5) == "4.5 breaths / min")
        #expect(Formats.countdown(seconds: 5) == "5")
        #expect(Formats.countdown(seconds: 0.2) == "1")
    }

    @Test("build names version, build number and commit")
    func build() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1",
                                   "StrapLogCommit": "dd795a4-dirty"]
        #expect(Formats.build(info) == "0.1.0 (1) · dd795a4-dirty")
        #expect(Formats.build([:]) == "? (?) · unstamped")
    }

    @Test("export location names the Files path for iCloud and the local fallback")
    func exportLocation() {
        let cloud = URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/iCloud~com~personalscience~straplog/Documents/x.sqlite")
        let local = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/ID/Documents/StrapLog/x.sqlite")
        #expect(Formats.exportLocation(cloud) == "Files → iCloud Drive → StrapLog → x.sqlite")
        #expect(Formats.exportLocation(local) == "Files → On My iPhone → StrapLog → StrapLog/x.sqlite")
    }

    @Test("the strap hint shows only while unlinked; switching is refused while recording")
    func strapHints() {
        #expect(Formats.strapHint(.connected(deviceId: "A")) == nil)
        #expect(Formats.strapHint(.searching)?.contains("wet electrodes") == true)
        #expect(Formats.strapHint(.bluetoothOff)?.contains("Bluetooth") == true)
        #expect(Formats.switchStrapFooter(recording: true) == "Stop recording to switch straps.")
    }
}
