import ActivityKit
import Foundation
import OSLog
import StrapLogCore

/// Shows `LiveStatus` as an ActivityKit Live Activity: Lock Screen, Dynamic Island, StandBy and
/// the Watch Smart Stack. ActivityKit only starts an activity from the foreground (or from a
/// `LiveActivityIntent`); a refused start is retried with the next status, so it appears once
/// the app is opened. The same retry replaces an activity the system ended at its 8 h limit.
@MainActor
final class LiveActivityDisplay: LiveStatusDisplay {
    private var activity: Activity<LiveRecordingAttributes>?
    /// Updates run in order, one at a time.
    private var queue: Task<Void, Never>?
    private let log = Logger(subsystem: "com.personalscience.straplog", category: "LiveActivity")

    func show(_ status: LiveStatus?) {
        let previous = queue
        queue = Task { [weak self] in
            await previous?.value
            await self?.apply(status)
        }
    }

    private func apply(_ status: LiveStatus?) async {
        guard let status else { return await endAll() }
        let content = ActivityContent(state: status,
                                      staleDate: Date().addingTimeInterval(Double(LiveStatus.staleAfterMs) / 1000))
        if let current = live(for: status) {
            await current.update(content)
            return
        }
        await endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(attributes: LiveRecordingAttributes(startedAtMs: status.startedAtMs),
                                            content: content)
        } catch {
            log.info("Live Activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The running activity for `status`'s recording, adopting one left by an earlier launch.
    private func live(for status: LiveStatus) -> Activity<LiveRecordingAttributes>? {
        let running = [activity].compactMap { $0 } + Activity<LiveRecordingAttributes>.activities
        activity = running.first {
            $0.attributes.startedAtMs == status.startedAtMs && $0.activityState == .active
        }
        return activity
    }

    private func endAll() async {
        for running in Activity<LiveRecordingAttributes>.activities {
            await running.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }
}
