/// What a `HeartSource`'s sensor can do beyond heart rate and RR, so the shared screens show
/// only what it can deliver. The default is the Polar H10's.
public struct SensorCapabilities: Sendable, Equatable {
    /// Streams live ECG (`setECGStreaming`).
    public var ecg: Bool
    public var placement: SensorPlacement
    /// Streams raw PPG and temperature (ArmLog's armband), so the recording screen shows them.
    public var optical: Bool
    /// Its RR intervals are accurate beat by beat, enough to follow heart rate through each
    /// breath (`RSATracker`). True for the H10 and replay; the armband stays false until its
    /// RR passes the check in straplog-9fr.8.
    public var beatToBeat: Bool

    public init(ecg: Bool = true, placement: SensorPlacement = .chest, optical: Bool = false,
                beatToBeat: Bool = true) {
        self.ecg = ecg
        self.placement = placement
        self.optical = optical
        self.beatToBeat = beatToBeat
    }
}
