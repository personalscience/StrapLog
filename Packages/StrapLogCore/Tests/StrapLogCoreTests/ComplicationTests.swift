import Foundation
import Testing
@testable import StrapLogCore

/// When the Watch face's complication reloads, and how its snapshot travels and is stored.
@Suite("Complication")
struct ComplicationTests {
    func status(startedAtMs: Int64 = 1_000, heartRate: Int? = 60, linked: Bool = true) -> LiveStatus {
        LiveStatus(name: "n", activity: "sleep", startedAtMs: startedAtMs, heartRate: heartRate, contact: true,
                   linked: linked, alpha1: nil, rmssd: nil, battery: 80, markers: [], markerCount: 0)
    }

    func snapshot(_ status: LiveStatus?, atMs: Int64 = 0) -> ComplicationSnapshot {
        ComplicationSnapshot(status: status, receivedAtMs: atMs)
    }

    @Test("starts, stops, new recordings and link changes reload the face")
    func transitionsReload() {
        #expect(snapshot(nil).replaces(nil), "the first snapshot always shows")
        #expect(snapshot(status()).replaces(snapshot(nil)))
        #expect(snapshot(nil).replaces(snapshot(status())))
        #expect(snapshot(status(startedAtMs: 2_000)).replaces(snapshot(status())))
        #expect(snapshot(status(linked: false)).replaces(snapshot(status())))
        #expect(snapshot(status()).replaces(snapshot(status(linked: false))), "recovery shows too")
    }

    @Test("heart rate alone reloads only once the shown one is 15 minutes old")
    func heartRateBudgeted() {
        let shown = snapshot(status(heartRate: 60), atMs: 0)
        #expect(!snapshot(status(heartRate: 90), atMs: ComplicationSnapshot.heartRateRefreshMs - 1).replaces(shown))
        #expect(snapshot(status(heartRate: 60), atMs: ComplicationSnapshot.heartRateRefreshMs).replaces(shown))
        #expect(!snapshot(nil, atMs: ComplicationSnapshot.heartRateRefreshMs).replaces(snapshot(nil)),
                "idle stays idle without reloads")
    }

    @Test("complication info carries the status, or marks idle")
    func payload() {
        let recording = WatchPayload.complicationInfo(for: status())
        #expect(WatchPayload.isComplicationInfo(recording))
        #expect(WatchPayload.status(in: recording) == status())
        let idle = WatchPayload.complicationInfo(for: nil)
        #expect(WatchPayload.isComplicationInfo(idle) && WatchPayload.status(in: idle) == nil)
        #expect(!WatchPayload.isComplicationInfo(WatchPayload.message(for: .markNext)))
    }

    @Test("the store round-trips a snapshot")
    func store() throws {
        let suite = "ComplicationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ComplicationStore(defaults: defaults)
        #expect(store.load() == nil)
        store.save(snapshot(status(), atMs: 42))
        #expect(store.load() == snapshot(status(), atMs: 42))
    }
}
