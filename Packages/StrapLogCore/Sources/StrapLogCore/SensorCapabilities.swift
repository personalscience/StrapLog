/// What a `HeartSource`'s sensor can do beyond heart rate and RR, so the shared screens show
/// only what it can deliver. The default is the Polar H10's.
public struct SensorCapabilities: Sendable, Equatable {
    /// Streams live ECG (`setECGStreaming`).
    public var ecg: Bool
    public var placement: SensorPlacement

    public init(ecg: Bool = true, placement: SensorPlacement = .chest) {
        self.ecg = ecg
        self.placement = placement
    }
}
