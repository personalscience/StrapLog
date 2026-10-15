import CoreBluetooth
import Foundation
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

    private let api: PolarBleApi
    private let clock: any WallClock
    private let defaults: UserDefaults
    private let continuation = Mutex<AsyncStream<SensorEvent>.Continuation?>(nil)
    private let searchTask = Mutex<Task<Void, Never>?>(nil)

    init(clock: any WallClock = SystemClock(), defaults: UserDefaults = .standard) {
        self.clock = clock
        self.defaults = defaults
        self.api = PolarBleApiDefaultImpl.polarImplementation(
            DispatchQueue(label: "com.personalscience.straplog.polar"),
            features: [.feature_hr, .feature_battery_info, .feature_device_info],
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
            }
        }
        searchTask.withLock { $0?.cancel(); $0 = task }
    }

    private func emit(_ payload: SensorEvent.Payload) {
        let event = SensorEvent(atMs: clock.nowMs(), payload)
        continuation.withLock { _ = $0?.yield(event) }
    }
}

extension PolarHeartSource: PolarBleApiObserver {
    func deviceConnecting(_ identifier: PolarDeviceInfo) {}

    func deviceConnected(_ identifier: PolarDeviceInfo) {
        emit(.connected(deviceId: identifier.deviceId, firmware: nil))
    }

    func deviceDisconnected(_ identifier: PolarDeviceInfo, info: PolarBleDisconnectInfo) {
        emit(.disconnected(reason: "\(info.reason)"))
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
    func disInformationReceived(_ identifier: String, uuid: CBUUID, value: String) {}
    func disInformationReceivedWithKeysAsStrings(_ identifier: String, key: String, value: String) {}
}

extension PolarHeartSource: PolarBleApiPowerStateObserver {
    func blePowerOn() { emit(.bluetooth(poweredOn: true)) }
    func blePowerOff() { emit(.bluetooth(poweredOn: false)) }
}
