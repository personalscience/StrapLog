/// Decides which statuses the phone pushes to the Watch face as complication user info, whose
/// daily budget (about 50) is too small for every status: a start or stop, and an hourly
/// check-in while recording, so a face that hears nothing for long can say so
/// (`ComplicationSnapshot.recordingShownMs`).
public struct FacePushPolicy: Sendable {
    public static let checkInMs: Int64 = 60 * 60_000

    /// The recording (its `startedAtMs`, nil for idle) the face last heard about; unset at
    /// first, so the first status always goes.
    private var recording: Int64??
    private var pushedAtMs: Int64 = 0

    public init() {}

    /// Whether `status`, arriving at `nowMs`, should go to the face; records it as sent if so.
    public mutating func shouldPush(_ status: LiveStatus?, nowMs: Int64) -> Bool {
        let changed = recording != .some(status?.startedAtMs)
        let checkIn = status != nil && nowMs - pushedAtMs >= Self.checkInMs
        guard changed || checkIn else { return false }
        recording = .some(status?.startedAtMs)
        pushedAtMs = nowMs
        return true
    }
}
