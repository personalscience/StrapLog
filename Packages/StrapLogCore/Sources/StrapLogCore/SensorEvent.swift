/// Something a `HeartSource` observed, stamped with the phone's receive time.
public struct SensorEvent: Sendable, Equatable {
    public enum Payload: Sendable, Equatable {
        /// One HR notification. `rr1024` are the RR intervals in 1/1024 s, oldest first (0–3+).
        /// `contact` is nil when the sensor does not report skin contact.
        case heartRate(bpm: Int, contact: Bool?, rr1024: [Int])
        case connected(deviceId: String, firmware: String?)
        case disconnected(reason: String?)
        case battery(percent: Int)
        case bluetooth(poweredOn: Bool)
    }

    /// Unix epoch ms UTC at which the phone received it.
    public var atMs: Int64
    public var payload: Payload

    public init(atMs: Int64, _ payload: Payload) {
        self.atMs = atMs
        self.payload = payload
    }
}
