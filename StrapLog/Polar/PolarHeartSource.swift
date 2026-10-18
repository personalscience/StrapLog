import CoreBluetooth
import Foundation
import OSLog
@preconcurrency import PolarBleSdk
import StrapLogCore
import Synchronization

/// The only bridge between the Polar SDK and the app. Connects to the remembered H10
/// (or the first one found by name) and turns SDK callbacks into `SensorEvent`s stamped
/// with the phone's receive time. Deliberately thin: everything downstream is tested
/// through `HeartSource` fakes. The SDK reconnects automatically after drops.
final class PolarHeartSource: NSObject, HeartSource, @unchecked Sendable {
    static let deviceIdKey = "polarDeviceId"
    private static let nameFragment = "H10"
    /// Turns on CoreBluetooth state restoration: if iOS kills the app while connected, a
    /// later event from the strap relaunches it in the background (docs/BACKGROUND.md).
    private static let restoreIdentifier = "com.personalscience.straplog.central"
    /// Accelerometer: 25 Hz is plenty for per-second motion; 8 G never clips a fall or a sprint.
    private static let accSampleRate: UInt32 = 25
    private static let accRangeG: UInt32 = 8
    private static let log = Logger(subsystem: "com.personalscience.straplog", category: "polar")

    private let api: PolarBleApi
    private let clock: any WallClock
    private let defaults: UserDefaults
    private let continuation = Mutex<AsyncStream<SensorEvent>.Continuation?>(nil)
    private let searchTask = Mutex<Task<Void, Never>?>(nil)
    /// The device whose online streaming (PMD) is ready, or nil while disconnected.
    private let streamingDevice = Mutex<String?>(nil)
    private let motionWanted = Mutex(false)
    private let motionTask = Mutex<Task<Void, Never>?>(nil)
    private let heartFilter = Mutex(DuplicateHeartFilter())
    /// The strap `forgetDevice` dropped: its disconnect is expected, so it is not reported.
    private let forgotten = Mutex<String?>(nil)
    /// How long a failed search waits before trying again.
    private static let searchRetry = Duration.seconds(5)

    init(clock: any WallClock = SystemClock(), defaults: UserDefaults = .standard) {
        self.clock = clock
        self.defaults = defaults
        self.api = PolarBleApiDefaultImpl.polarImplementation(
            DispatchQueue(label: "com.personalscience.straplog.polar"),
            features: [.feature_hr, .feature_battery_info, .feature_device_info, .feature_polar_online_streaming],
            restoreIdentifier: Self.restoreIdentifier)
        super.init()
        // `PolarBleApi` is not class-bound, so its setters need a `var`; the instance is a class.
        var api = self.api
        api.observer = self
        // Deprecated in favour of `startHrStreaming`, but only the observer gives RR in
        // 1/1024 s; the one remaining build warning is expected (docs/SDK-NOTES.md).
        api.deviceHrObserver = self
        api.deviceInfoObserver = self
        api.powerStateObserver = self
        api.deviceFeaturesObserver = self
    }

    /// One consumer for the app's lifetime; calling again replaces the previous stream.
    func events() -> AsyncStream<SensorEvent> {
        let (stream, cont) = AsyncStream.makeStream(of: SensorEvent.self)
        continuation.withLock { $0?.finish(); $0 = cont }
        connect()
        return stream
    }

    private func connect() {
        if let id = defaults.string(forKey: Self.deviceIdKey) {
            do { try api.connectToDevice(id) } catch { emit(.disconnected(reason: "connect failed: \(error)")) }
            return
        }
        let task = Task { [api, defaults] in
            do {
                for try await device in api.searchForDevice(withNameContaining: Self.nameFragment) {
                    defaults.set(device.deviceId, forKey: Self.deviceIdKey)
                    try api.connectToDevice(device.deviceId)
                    break
                }
            } catch {
                self.emit(.disconnected(reason: "search failed: \(error)"))
                try? await Task.sleep(for: Self.searchRetry)
                if !Task.isCancelled { self.connect() }
            }
        }
        searchTask.withLock { $0?.cancel(); $0 = task }
    }

    func forgetDevice() {
        if let id = defaults.string(forKey: Self.deviceIdKey) {
            defaults.removeObject(forKey: Self.deviceIdKey)
            forgotten.withLock { $0 = id }
            try? api.disconnectFromDevice(id)
        }
        connect()
    }

    /// Wanted state survives reconnects: the stream (re)starts whenever streaming becomes ready.
    func setMotionStreaming(_ on: Bool) {
        motionWanted.withLock { $0 = on }
        guard let id = streamingDevice.withLock({ $0 }) else { return }
        if on { startMotion(id) } else { stopMotion(id) }
    }

    private func startMotion(_ id: String) {
        let task = Task { [api] in
            // A stream left running (by a killed process, say) makes a new start fail; clear it.
            try? await api.stopStreaming(id, type: .acc)
            do {
                let available = try await api.requestStreamSettings(id, feature: .acc)
                for try await batch in api.startAccStreaming(id, settings: try Self.accSettings(from: available)) {
                    self.emit(.motion(samples: batch.map {
                        AccSample(deviceNs: $0.timeStamp, x: Int($0.x), y: Int($0.y), z: Int($0.z))
                    }))
                }
            } catch {
                if !Task.isCancelled { Self.log.error("ACC stream ended: \(String(describing: error))") }
            }
        }
        motionTask.withLock { $0?.cancel(); $0 = task }
    }

    /// The SDK requires ACC to be stopped explicitly (KnownIssues); cancelling alone is not enough.
    private func stopMotion(_ id: String) {
        motionTask.withLock { $0?.cancel(); $0 = nil }
        Task { [api] in try? await api.stopStreaming(id, type: .acc) }
    }

    /// 25 Hz and 8 G when offered (the H10 offers both), else the nearest; other settings at max.
    private static func accSettings(from available: PolarSensorSetting) throws -> PolarSensorSetting {
        var chosen: [PolarSensorSetting.SettingType: UInt32] = [:]
        for (type, values) in available.settings {
            chosen[type] = switch type {
            case .sampleRate: values.contains(accSampleRate) ? accSampleRate : values.min()
            case .range: values.contains(accRangeG) ? accRangeG : values.max()
            default: values.max()
            }
        }
        return try PolarSensorSetting(chosen)
    }

    private func emit(_ payload: SensorEvent.Payload) {
        let event = SensorEvent(atMs: clock.nowMs(), payload)
        // The SDK can run two HR observer tasks on one connection (DuplicateHeartFilter explains
        // why); each calls the observer synchronously, so the current task names the observer.
        let observer = withUnsafeCurrentTask { $0?.hashValue }
        guard heartFilter.withLock({ $0.admit(event, observer: observer) }) else { return }
        continuation.withLock { _ = $0?.yield(event) }
    }
}

extension PolarHeartSource: PolarBleApiObserver {
    func deviceConnecting(_ identifier: PolarDeviceInfo) {}

    func deviceConnected(_ identifier: PolarDeviceInfo) {
        emit(.connected(deviceId: identifier.deviceId, firmware: nil))
    }

    func deviceDisconnected(_ identifier: PolarDeviceInfo, info: PolarBleDisconnectInfo) {
        streamingDevice.withLock { $0 = nil }
        motionTask.withLock { $0?.cancel(); $0 = nil }
        let expected = forgotten.withLock { id in
            defer { if id == identifier.deviceId { id = nil } }
            return id == identifier.deviceId
        }
        guard !expected else { return }
        emit(.disconnected(reason: "\(info.reason)"))
    }
}

extension PolarHeartSource: PolarBleApiDeviceFeaturesObserver {
    /// After every (re)connection: resume the ACC stream if a recording wants it.
    func bleSdkFeatureReady(_ identifier: String, feature: PolarBleSdkFeature) {
        guard feature == .feature_polar_online_streaming else { return }
        streamingDevice.withLock { $0 = identifier }
        if motionWanted.withLock({ $0 }) { startMotion(identifier) }
    }
}

extension PolarHeartSource: PolarBleApiDeviceHrObserver {
    /// `rrs` are in 1/1024 s, the H10's native unit (`rrsMs` is already rounded).
    func hrValueReceived(_ identifier: String,
                         data: (hr: UInt8, rrs: [Int], rrsMs: [Int], contact: Bool, contactSupported: Bool)) {
        emit(.heartRate(bpm: Int(data.hr), contact: data.contactSupported ? data.contact : nil, rr1024: data.rrs))
    }
}

extension PolarHeartSource: PolarBleApiDeviceInfoObserver {
    func batteryLevelReceived(_ identifier: String, batteryLevel: UInt) {
        emit(.battery(percent: Int(batteryLevel)))
    }

    func batteryChargingStatusReceived(_ identifier: String, chargingStatus: BleBasClient.ChargeState) {}
    /// DIS strings, read once per connection: firmware revision (0x2A26) and serial number (0x2A25).
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {
        switch uuid {
        case CBUUID(string: "2A26"): emit(.firmware(value))
        case CBUUID(string: "2A25"): emit(.serialNumber(value))
        default: break
        }
    }
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {}
}

extension PolarHeartSource: PolarBleApiPowerStateObserver {
    func blePowerOn() { emit(.bluetooth(poweredOn: true)) }
    func blePowerOff() { emit(.bluetooth(poweredOn: false)) }
}
