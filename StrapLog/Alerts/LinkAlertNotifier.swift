import Foundation
import OSLog
import StrapLogCore
import UserNotifications

/// Posts a notification when the open recording stops getting beats (`LinkAlarm`). With the
/// iPhone locked, iOS shows it on the Watch, so a slipped strap buzzes the wrist whether or not
/// the Watch app is running; the Watch app buzzes too while it is on screen. Silent for overnight
/// recordings. Time-sensitive, so a Sleep Focus that allows it lets it through. Only this file imports UserNotifications.
@MainActor
final class LinkAlertNotifier: LiveStatusDisplay {
    private let log = Logger(subsystem: "com.personalscience.straplog", category: "LinkAlert")
    private let center = UNUserNotificationCenter.current()
    private var alarm = LinkAlarm()
    private var asked = false
    private static let identifier = "link-alert"

    func show(_ status: LiveStatus?) {
        if status != nil { askOnce() }
        if let problem = alarm.update(status) {
            post(problem)
        } else if status?.problem(isStale: false) == nil {
            // Beats are back, or the recording ended: the warning no longer applies.
            center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        }
    }

    /// Asked at the first recording rather than at launch, which can be a background restoration.
    private func askOnce() {
        guard !asked else { return }
        asked = true
        center.requestAuthorization(options: [.alert, .sound]) { [log] granted, error in
            if !granted { log.info("Notifications not allowed: \(error?.localizedDescription ?? "denied", privacy: .public)") }
        }
    }

    private func post(_ problem: LinkProblem) {
        let content = UNMutableNotificationContent()
        content.title = "StrapLog: no beats"
        content.body = problem.message
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: nil)) { [log] error in
            if let error { log.error("Link alert not posted: \(error.localizedDescription, privacy: .public)") }
        }
    }
}
