import Foundation

/// What the complication can vouch for at a moment (`ComplicationSnapshot.face(at:)`).
public enum ComplicationFace: Sendable, Equatable {
    case idle
    /// `heartRate` nil once it is too old to show.
    case recording(LiveStatus, heartRate: Int?)
    /// A recording was on, but the phone has not been heard from since `since`.
    case noWord(since: Date)
}
