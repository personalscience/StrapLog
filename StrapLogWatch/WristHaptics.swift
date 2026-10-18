import StrapLogCore
import WatchKit

/// The Watch's taps. watchOS plays them only while the app is on screen; with the app in the
/// background the phone's `LinkAlertNotifier` notification buzzes the wrist instead.
enum WristHaptics {
    /// A command left the Watch.
    static func sent() {
        WKInterfaceDevice.current().play(.click)
    }

    /// The phone could not start or stop.
    static func failed() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// Beats stopped: the strongest pattern, twice, so it gets noticed (never overnight; `LinkAlarm`).
    static func alert(_ problem: LinkProblem) {
        WKInterfaceDevice.current().play(.failure)
        Task {
            try? await Task.sleep(for: .seconds(1))
            WKInterfaceDevice.current().play(.failure)
        }
    }
}
