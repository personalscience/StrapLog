import Foundation
import Testing
@testable import StrapLogCore

/// `RemoteCommand` and `LiveStatus` as they cross WatchConnectivity.
@MainActor
@Suite("RemoteCommand")
struct RemoteCommandTests {
    let status = LiveStatus(name: "night", activity: "sleep", startedAtMs: 1_760_600_000_000, heartRate: 54,
                            contact: true, linked: true, alpha1: 1.12, rmssd: 48, battery: 80,
                            markers: ["awake", "lights_out"], markerCount: 1, lastMarkerLabel: "awake",
                            lastMarkerText: "awake", lastMarkerAtMs: 1_760_600_060_000)

    @Test("every command survives a round trip through a Watch message", arguments: [
        RemoteCommand.start(activity: "sleep"), .start(activity: "run", name: "tempo"), .stop, .mark("awake"),
        .mark("knee twinge"),
    ])
    func commandRoundTrip(_ command: RemoteCommand) {
        #expect(WatchPayload.command(in: WatchPayload.message(for: command)) == command)
    }

    @Test("a message without a readable command is ignored")
    func junkMessage() {
        #expect(WatchPayload.command(in: [:]) == nil)
        #expect(WatchPayload.command(in: ["command": Data("{\"fly\":{}}".utf8)]) == nil)
    }

    @Test("status survives the application context; idle is an empty context")
    func statusRoundTrip() {
        #expect(WatchPayload.status(in: WatchPayload.context(for: status)) == status)
        #expect(WatchPayload.context(for: nil).isEmpty)
        #expect(WatchPayload.status(in: [:]) == nil)
    }

    @Test("the fan-out shows each status on every display")
    func fanOut() {
        let a = RecordingDisplay(), b = RecordingDisplay()
        LiveStatusFanOut([a, b]).show(status)
        LiveStatusFanOut([a, b]).show(nil)
        #expect(a.shown == [status, nil])
        #expect(b.shown == [status, nil])
    }
}
