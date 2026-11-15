/// What a `HeartSource`'s sensor can do beyond heart rate and RR, so the shared screens show
/// only what it can deliver. The default is the Polar H10's.
public struct SensorCapabilities: Sendable, Equatable {
    /// Streams live ECG (`setECGStreaming`).
    public var ecg: Bool
    public var placement: SensorPlacement
    /// Streams raw PPG and temperature (BaroLog's armband), so the recording screen shows them.
    public var optical: Bool

    public init(ecg: Bool = true, placement: SensorPlacement = .chest, optical: Bool = false) {
        self.ecg = ecg
        self.placement = placement
        self.optical = optical
    }
}
