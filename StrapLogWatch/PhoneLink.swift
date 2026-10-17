import Foundation
import Observation
import StrapLogCore
import WatchConnectivity

/// The Watch's end of WatchConnectivity: the phone's latest `LiveStatus` (nil while it is not
/// recording), and `RemoteCommand`s sent back. The phone records; the Watch shows, marks, starts
/// and stops it, and buzzes when beats stop (`LinkAlarm`).
@MainActor
@Observable
final class PhoneLink: NSObject {
    private(set) var status: LiveStatus?
    /// When the latest context arrived; nil until the first one.
    private(set) var receivedAt: Date?
    /// The start or stop sent and not yet landed, or the phone's failure answer to it.
    private(set) var pending: PendingCommand?
    @ObservationIgnored private var alarm = LinkAlarm()
    @ObservationIgnored private var isActivated = false
    @ObservationIgnored private var activationWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var staleWatch: Task<Void, Never>?

    /// How often to check for a phone gone quiet while the app runs.
    static let staleCheckInterval: Duration = .seconds(5)

    func activate() {
        guard WCSession.isSupported(), WCSession.default.delegate == nil else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        staleWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.staleCheckInterval)
                self?.checkAlarm()
            }
        }
    }

    /// Whether the shown status is older than `LiveStatus.staleAfterMs`: the phone app or its
    /// link has gone quiet.
    func isStale(at now: Date) -> Bool {
        guard status != nil, let receivedAt else { return false }
        return now.timeIntervalSince(receivedAt) * 1000 > Double(LiveStatus.staleAfterMs)
    }

    /// Sends `command` once the session is up: now if the phone is reachable (which wakes its
    /// app), else queued. Waits for activation so an intent launched cold does not drop it.
    func send(_ command: RemoteCommand) async {
        activate()
        if !isActivated { await withCheckedContinuation { activationWaiters.append($0) } }
        let session = WCSession.default
        let message = WatchPayload.message(for: command)
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in session.transferUserInfo(message) }
        } else {
            session.transferUserInfo(message)
        }
        WristHaptics.sent()
    }

    /// Sends a start or stop and waits for it to land: the phone's reply, or failing that the
    /// application context once a queued command runs. A sent message wakes the phone app in
    /// the background, so this works with the iPhone locked in a pocket.
    func request(_ command: RemoteCommand) async {
        pending = PendingCommand(command)
        activate()
        if !isActivated { await withCheckedContinuation { activationWaiters.append($0) } }
        let session = WCSession.default
        let message = WatchPayload.message(for: command)
        WristHaptics.sent()
        guard session.isReachable else { return queue(message) }
        session.sendMessage(message) { [weak self] payload in
            let reply = WatchPayload.reply(in: payload)
            Task { @MainActor in self?.receive(reply) }
        } errorHandler: { [weak self] _ in
            Task { @MainActor in self?.queue(message) }
        }
    }

    /// Clears a failure, or stops waiting for a queued command and withdraws it.
    func dismissPending() {
        if pending?.queued == true {
            for transfer in WCSession.default.outstandingUserInfoTransfers { transfer.cancel() }
        }
        pending = nil
    }

    private func queue(_ message: [String: Any]) {
        guard pending != nil else { return }
        WCSession.default.transferUserInfo(message)
        pending?.queued = true
    }

    private func receive(_ reply: CommandReply?) {
        guard let reply else { return }
        if let failure = reply.failure {
            pending?.failure = failure
            WristHaptics.failed()
        }
        receive(reply.status)
    }

    private func didActivate() {
        isActivated = true
        for waiter in activationWaiters { waiter.resume() }
        activationWaiters = []
    }

    private func receive(_ status: LiveStatus?) {
        self.status = status
        receivedAt = .now
        if let pending, pending.failure == nil, pending.isSettled(by: status) { self.pending = nil }
        checkAlarm()
    }

    private func checkAlarm() {
        if let problem = alarm.update(status, isStale: isStale(at: .now)) { WristHaptics.alert(problem) }
    }
}

extension PhoneLink: WCSessionDelegate {
    /// Picks up the context delivered while the app was not running.
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let context = session.receivedApplicationContext
        let status = context.isEmpty ? nil : WatchPayload.status(in: context)
        let hasContext = !context.isEmpty
        Task { @MainActor in
            if hasContext { receive(status) }
            didActivate()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let status = WatchPayload.status(in: context)
        Task { @MainActor in receive(status) }
    }
}
