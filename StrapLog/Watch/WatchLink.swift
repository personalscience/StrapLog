import Foundation
import OSLog
import StrapLogCore
import WatchConnectivity

/// The phone's end of WatchConnectivity: shows `LiveStatus` on the Watch app through the
/// application context (the latest value wins, delivered when the Watch app next runs), and
/// runs the Watch's `RemoteCommand`s through `Launcher`. The phone stays the only recorder.
/// Only this file imports WatchConnectivity, as only `LiveActivityDisplay` imports ActivityKit.
@MainActor
final class WatchLink: NSObject, LiveStatusDisplay {
    private let log = Logger(subsystem: "com.personalscience.straplog", category: "WatchLink")
    private var launcher: Launcher?
    /// The newest status, kept until the session can take it.
    private var pending: LiveStatus??

    /// Call once at launch: a message can be what launched the app in the background.
    func activate(running launcher: Launcher) {
        self.launcher = launcher
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func show(_ status: LiveStatus?) {
        pending = .some(status)
        flush()
    }

    private func flush() {
        let session = WCSession.default
        guard let status = pending, WCSession.isSupported(), session.activationState == .activated else { return }
        // Without a paired Watch running the app there is no one to tell; the next status retries.
        guard session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(WatchPayload.context(for: status))
            pending = nil
        } catch {
            log.info("Watch context not sent: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func run(_ command: RemoteCommand) async {
        guard let launcher else { return }
        do {
            let outcome = try await launcher.run(command)
            log.info("Watch \(String(describing: command), privacy: .public): \(String(describing: outcome), privacy: .public)")
        } catch {
            log.error("Watch command failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor in flush() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in flush() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Switching to another paired Watch: activate again for the new one.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(message)
    }

    /// Commands queued while the phone was unreachable.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(userInfo)
    }

    /// Decodes off the main actor: the dictionary is not `Sendable`, the command is.
    private nonisolated func receive(_ payload: [String: Any]) {
        guard let command = WatchPayload.command(in: payload) else { return }
        Task { @MainActor in await run(command) }
    }
}
