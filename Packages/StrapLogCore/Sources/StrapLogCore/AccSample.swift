/// One accelerometer sample from the strap, in mg (1 g ≈ 1000 at rest).
/// `deviceNs` is the sensor's own clock; only differences within a batch are trusted,
/// so wall-clock time comes from the phone's receipt (`MotionReducer.timesMs`).
public struct AccSample: Sendable, Equatable {
    public var deviceNs: UInt64
    public var x: Int
    public var y: Int
    public var z: Int

    public init(deviceNs: UInt64, x: Int, y: Int, z: Int) {
        self.deviceNs = deviceNs
        self.x = x
        self.y = y
        self.z = z
    }
}
