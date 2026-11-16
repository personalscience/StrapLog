/// What a `HeartSource`'s sensor can do beyond heart rate and RR, so the shared screens show
/// only what it can deliver. The default is the Polar H10's.
public struct SensorCapabilities: Sendable, Equatable {
    /// Streams live ECG (`setECGStreaming`).
    public var ecg: Bool
    public var placement: SensorPlacement
    /// Streams raw PPG and temperature (ArmLog's armband), so the recording screen shows them.
    public var optical: Bool
    /// Its RR intervals are accurate beat by beat, enough to follow heart rate through each
    /// breath (`RSATracker`, the resonance finder). True for the H10, replay and, since
    /// straplog-9fr.8, the armband: against the H10 its swing is within 0.5 bpm and its sync within
    /// 0.1 at every rate (2026-11-15), though its beat-level HRV is not (RMSSD ~11% high).
    public var beatToBeat: Bool

    public init(ecg: Bool = true, placement: SensorPlacement = .chest, optical: Bool = false,
                beatToBeat: Bool = true) {
        self.ecg = ecg
        self.placement = placement
        self.optical = optical
        self.beatToBeat = beatToBeat
    }
}
