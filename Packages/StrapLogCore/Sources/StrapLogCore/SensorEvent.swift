/// Something a `HeartSource` observed, stamped with the phone's receive time.
public struct SensorEvent: Sendable, Equatable {
    public enum Payload: Sendable, Equatable {
        /// One HR notification. `rr1024` are the RR intervals in 1/1024 s, oldest first (0–3+).
        /// `contact` is nil when the sensor does not report skin contact.
        case heartRate(bpm: Int, contact: Bool?, rr1024: [Int])
        case connected(deviceId: String, firmware: String?)
        case disconnected(reason: String?)
        case battery(percent: Int)
        /// Device Information Service strings; they arrive some seconds after `connected`.
        case firmware(String)
        case serialNumber(String)
        case bluetooth(poweredOn: Bool)
        /// One accelerometer notification, oldest sample first. Streamed only while recording or
        /// while the pacer screen shows the measured breath; written only while recording.
        case motion(samples: [AccSample])
        /// One ECG notification, oldest sample first. Streamed only while the pacer screen
        /// shows it, and never written: display only.
        case ecg(samples: [EcgSample])
        /// Raw PPG readings, oldest first, each with its own receive time. Streamed with motion
        /// (`setMotionStreaming`); written only while recording, to `ppg`.
        case ppg(samples: [PpgSample])
        /// A temperature report. Written only while recording, to `temperature`, and only when a
        /// value changes or a minute has passed since the last row.
        case temperature(TemperatureReading)
    }

    /// Unix epoch ms UTC at which the phone received it.
    public var atMs: Int64
    public var payload: Payload

    public init(atMs: Int64, _ payload: Payload) {
        self.atMs = atMs
        self.payload = payload
    }
}
