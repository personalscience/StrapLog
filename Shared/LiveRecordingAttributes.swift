import ActivityKit
import StrapLogCore

/// The Live Activity of one open recording, compiled into the app and the widget extension.
/// Everything that changes travels in `LiveStatus`.
struct LiveRecordingAttributes: ActivityAttributes {
    typealias ContentState = LiveStatus

    /// Identifies the recording, so a relaunched app adopts its own activity.
    let startedAtMs: Int64
}
