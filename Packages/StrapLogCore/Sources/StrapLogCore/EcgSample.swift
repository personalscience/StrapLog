/// One ECG sample from the strap (H10: single lead, 130 Hz), in µV. `deviceNs` is the sensor's
/// own clock; `EcgTrace` maps it onto the phone's.
public struct EcgSample: Sendable, Equatable {
    public var deviceNs: UInt64
    public var microvolts: Int

    public init(deviceNs: UInt64, microvolts: Int) {
        self.deviceNs = deviceNs
        self.microvolts = microvolts
    }
}
