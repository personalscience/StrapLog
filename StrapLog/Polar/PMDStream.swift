import PolarBleSdk

/// The strap's online (PMD) streams the app uses, named once for the SDK's two vocabularies.
enum PMDStream: CaseIterable {
    /// Accelerometer, while recording.
    case motion
    /// ECG, while the pacer screen shows it.
    case ecg

    var measurement: PmdMeasurementType {
        switch self {
        case .motion: .acc
        case .ecg: .ecg
        }
    }

    var feature: PolarDeviceDataType {
        switch self {
        case .motion: .acc
        case .ecg: .ecg
        }
    }
}
