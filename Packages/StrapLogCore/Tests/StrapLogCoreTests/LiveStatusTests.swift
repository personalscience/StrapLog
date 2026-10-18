import Foundation
import Testing
@testable import StrapLogCore

@MainActor
@Suite("LiveStatus")
struct LiveStatusTests {
    let clock = FakeClock()
    let display = RecordingDisplay()
    let model: RecorderModel

    init() throws {
        model = RecorderModel(database: try .inMemory(), exports: ExportFolder(local: try scratchDirectory()),
                              clock: clock, display: display)
    }

    func play(_ script: [FakeHeartSource.Step]) async {
        await model.consume(FakeHeartSource(clock: clock, script: script))
    }

    @Test("idle shows nil; start shows the recording; stop ends it")
    func lifecycle() async {
        await model.launch()
        #expect(display.shown.count == 1)
        #expect(display.shown.last! == nil)

        await play([.emit(.connected(deviceId: "H10-1", firmware: nil)), .emit(.battery(percent: 82)), hr([1024], bpm: 58)])
        #expect(display.shown.count == 1, "nothing to show while idle")

        await model.start(.sleep, name: "night")
        let started = try? #require(display.shown.last ?? nil)
        #expect(started?.name == "night")
        #expect(started?.activity == "sleep")
        #expect(started?.heartRate == 58)
        #expect(started?.linked == true)
        #expect(started?.strapId == "H10-1", "the Watch's key to the strap's broadcasts")
        #expect(started?.markers == ActivityPreset.sleep.markers)
        #expect(started?.linkText == "Strap · 82 %")

        await model.stop()
        #expect(display.shown.last! == nil)
    }

    @Test("HR updates are throttled; a disconnect and a marker go out at once")
    func throttled() async {
        await model.launch()
        await play([.emit(.connected(deviceId: "H10-1", firmware: nil)), hr([1024], bpm: 60)])
        await model.start(name: "walk")
        let afterStart = display.shown.count

        await play([.wait(ms: 1000), hr([1000], bpm: 61), .wait(ms: 1000), hr([1000], bpm: 62)])
        #expect(display.shown.count == afterStart, "within 10 s of the last update")

        await play([.wait(ms: 9000), hr([1000], bpm: 70)])
        #expect(display.shown.count == afterStart + 1)
        #expect(display.shown.last??.heartRate == 70)

        await play([.emit(.disconnected(reason: nil))])
        #expect(display.shown.last??.linked == false)
        #expect(display.shown.last??.heartRate == nil)
        #expect(display.shown.last??.linkText == "Reconnecting…")

        await model.marker(label: "lights_out")
        let marked = display.shown.last ?? nil
        #expect(marked?.markerCount == 1)
        #expect(marked?.isLastMarker("lights_out") == true)
        #expect(marked?.isLastMarker("a") == false)
        #expect(marked?.markedText == "Marked lights out ·")
        #expect(marked?.lastMarkerAtMs == clock.nowMs())

        await model.marker(note: "coffee")
        #expect(display.shown.last??.lastMarkerLabel == nil)
        #expect(display.shown.last??.markedText == "Marked coffee ·")
    }

    @Test("display strings")
    func strings() {
        let s = LiveStatus(name: "n", activity: "other", startedAtMs: 0, heartRate: nil, contact: false, linked: true,
                           alpha1: 0.734, rmssd: 41.6, battery: nil, markers: [], markerCount: 0)
        #expect(s.heartRateText == "--")
        #expect(s.alpha1Text == "0.73")
        #expect(s.alpha1Band == .moderate)
        #expect(s.rmssdText == "42 ms")
        #expect(s.linkText == "No skin contact")
        #expect(s.needsAttention(isStale: false))
        #expect(s.footer(isStale: true).hasPrefix("No update"))
        #expect(LiveStatus.markerTitle("lights_out") == "lights out")
    }
}
