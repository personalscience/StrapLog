import Foundation
import Testing
@testable import StrapLogCore

/// A Watch start or stop waiting to land, and the phone's reply to it.
@Suite("PendingCommand")
struct PendingCommandTests {
    let status = LiveStatus(name: "night", activity: "sleep", startedAtMs: 1_760_600_000_000, heartRate: 54,
                            contact: true, linked: true, alpha1: nil, rmssd: nil, battery: 80,
                            markers: ["lights_out"], markerCount: 0, lastMarkerLabel: nil,
                            lastMarkerText: nil, lastMarkerAtMs: nil)

    @Test("a start settles on a recording, a stop on idle")
    func settles() {
        let start = PendingCommand(.start(activity: "sleep"))
        #expect(!start.isSettled(by: nil))
        #expect(start.isSettled(by: status))
        let stop = PendingCommand(.stop)
        #expect(!stop.isSettled(by: status))
        #expect(stop.isSettled(by: nil))
    }

    @Test("the wait names the activity, or the unreachable phone once queued")
    func waitingText() {
        var start = PendingCommand(.start(activity: "sleep"))
        #expect(start.waitingText == "Starting Sleep…")
        start.queued = true
        #expect(start.waitingText == "Waiting for iPhone…")
        #expect(PendingCommand(.stop).waitingText == "Stopping…")
    }

    @Test("a reply carries the status and only a failure's words", arguments: [nil, "Bluetooth is off."])
    func replyRoundTrip(_ failure: String?) {
        let outcome: CommandOutcome = failure.map { .failed($0) } ?? .notRecording
        let reply = CommandReply(outcome, status: status)
        #expect(reply.failure == failure)
        #expect(WatchPayload.reply(in: WatchPayload.message(for: reply)) == reply)
        #expect(WatchPayload.reply(in: WatchPayload.message(for: CommandReply(status: nil)))?.status == nil)
        #expect(WatchPayload.reply(in: [:]) == nil)
    }
}
