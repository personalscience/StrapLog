import Foundation
import Observation
import StrapLogCore
import WatchConnectivity

/// The Watch's end of WatchConnectivity: the phone's latest `LiveStatus` (nil while it is not
/// recording), and `RemoteCommand`s sent back. The phone records; the Watch only shows.
@MainActor
@Observable
final class PhoneLink: NSObject {
    private(set) var status: LiveStatus?
    /// When the latest context arrived; nil until the first one.
    private(set) var receivedAt: Date?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Whether the shown status is older than `LiveStatus.staleAfterMs`: the phone app or its
    /// link has gone quiet.
    func isStale(at now: Date) -> Bool {
        guard status != nil, let receivedAt else { return false }
        return now.timeIntervalSince(receivedAt) * 1000 > Double(LiveStatus.staleAfterMs)
    }

    /// Sends `command` now if the phone is reachable (which wakes its app), else queues it.
    func send(_ command: RemoteCommand) {
        let session = WCSession.default
        let message = WatchPayload.message(for: command)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in session.transferUserInfo(message) }
        } else {
            session.transferUserInfo(message)
        }
    }

    private func receive(_ status: LiveStatus?) {
        self.status = status
        receivedAt = .now
    }
}

extension PhoneLink: WCSessionDelegate {
    /// Picks up the context delivered while the app was not running.
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let context = session.receivedApplicationContext
        guard !context.isEmpty else { return }
        let status = WatchPayload.status(in: context)
        Task { @MainActor in receive(status) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let status = WatchPayload.status(in: context)
        Task { @MainActor in receive(status) }
    }
}
