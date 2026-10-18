/// Where the Watch takes the HR it shows (`HeartRateSourcePolicy`).
public enum HeartRateSource: Sendable, Equatable {
    /// The phone's `LiveStatus`: HR with α1 and the recording.
    case phone
    /// The strap's own broadcasts (`StrapBroadcast`): HR only, scanned while the phone is gone.
    case strap
    /// The app is not on screen; nothing scans.
    case idle
}
