import Foundation
import HRVKit
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

    @Test("no-beats line names the device and the 10 s threshold")
    func noBeats() {
        #expect(Formats.noBeats(device: "armband") == "No beats for 10 s: the armband may be moving or loose.")
    }

    @Test("armband temperatures and pulse/movement line, with dashes before data")
    func optical() {
        #expect(Formats.temperatures(TemperatureReading(ambientDeci: 315, skinDeci: 329, bodyDeci: 365))
                == "Skin 32.9° · Band 31.5° · Body 36.5°")
        #expect(Formats.temperatures(nil) == "Temperature —")
        #expect(Formats.pulseAndMovement(amplitude: 320, movementMg: 11.6) == "Pulse size 320 · Movement 12 mg")
        #expect(Formats.pulseAndMovement(amplitude: nil, movementMg: nil) == "Pulse size — · Movement —")
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
        // 2026-10-24 10:40:30 UTC is 03:40 in Pacific daylight time (UTC-7).
        let low = TrendPoint(atMs: 1_792_838_430_000, value: 46.4)
        #expect(Formats.overnightLow(lowest: low, tzOffsetS: -25_200, elapsedMs: 18_779_000) == "Low 46 at 03:40\n5 h 12 min")
        #expect(Formats.overnightLow(lowest: nil, tzOffsetS: 0, elapsedMs: 179_999) == "Low --\n2 min")
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

    @Test("training: script length in whole minutes; step with rate and time left")
    func training() {
        #expect(Formats.trainingScript(.calibration) == "calibration · 19 min")
        #expect(Formats.trainingScript(.rehearsal) == "rehearsal · 2 min")
        let follow = TrainingStep.paced("follow_6", say: "", rate: 6, seconds: 180)
        #expect(Formats.trainingStep(follow, secondsLeft: 83) == "follow_6 · 6.0/min · 1:23 left")
        #expect(Formats.trainingStep(.quiet("hold_1", say: "", seconds: 30), secondsLeft: 20) == "hold_1 · 0:20 left")
        #expect(Formats.trainingStep(nil, secondsLeft: nil) == "Starting…")
    }

    @Test("RSA: swing and sync with dashes before a fit; peak against the turn to out")
    func rsa() {
        let fit = CosinorFit(mean: 60, slope: 0, swing: 8.56, sync: 0.876, peakFraction: 0.6, n: 40)
        #expect(Formats.rsaSwing(fit) == "8.6 bpm")
        #expect(Formats.rsaSwing(nil) == "— bpm")
        #expect(Formats.rsaSync(fit) == "88%")
        #expect(Formats.rsaSync(nil) == "—")
        let six = BreathingPacer(breathsPerMinute: 6, startedAtMs: 0)
        #expect(Formats.rsaPeak(fit, pacer: six) == "HR peaks 1.0 s into the out-breath")
        let early = CosinorFit(mean: 60, slope: 0, swing: 8, sync: 0.8, peakFraction: 0.45, n: 40)
        #expect(Formats.rsaPeak(early, pacer: six) == "HR peaks 0.5 s before the out-breath")
        let wrapped = CosinorFit(mean: 60, slope: 0, swing: 8, sync: 0.8, peakFraction: 0.05, n: 40)
        #expect(Formats.rsaPeak(wrapped, pacer: six) == "HR peaks 4.5 s before the out-breath")
        let fourSix = BreathingPacer(breathsPerMinute: 6, ratio: .fourSix, startedAtMs: 0)
        #expect(Formats.rsaPeak(fit, pacer: fourSix) == "HR peaks 2.0 s into the out-breath")
    }

    @Test("RSA waiting line: before beats, warming up, before the first fit, then none")
    func rsaWaiting() {
        #expect(Formats.rsaWaiting(nil, connected: false, device: "H10") == "Needs the H10 connected")
        #expect(Formats.rsaWaiting(nil, connected: true, device: "H10") == "Waiting for heartbeats…")
        let warming = RSAReading(atMs: 0, trace: [], breaths: [], fit: nil, warmingUp: true)
        #expect(Formats.rsaWaiting(warming, connected: true, device: "H10") == "Follow the pacer: the trace fills as you breathe")
        let warm = RSAReading(atMs: 0, trace: [], breaths: [], fit: nil, warmingUp: false)
        #expect(Formats.rsaWaiting(warm, connected: true, device: "H10") == "Swing and sync after 4 full breaths")
        let fit = CosinorFit(mean: 60, slope: 0, swing: 8, sync: 0.8, peakFraction: 0.6, n: 40)
        #expect(Formats.rsaWaiting(RSAReading(atMs: 0, trace: [], breaths: [], fit: fit, warmingUp: false),
                                   connected: true, device: "H10") == nil)
    }
}
