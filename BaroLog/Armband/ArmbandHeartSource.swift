import ChileafKit
import CoreBluetooth
import Foundation
import OSLog
import StrapLogCore
import Synchronization

/// The only bridge between CoreBluetooth and the app: connects to the BaroShift armband
/// (`CL837-…`, a Chileaf CL831), subscribes to its notifications and hands the bytes to
/// `ArmbandTranslator`. Deliberately thin: decoding and batching are tested in ChileafKit.
///
/// **Read-only by construction.** It subscribes and reads; it never writes to the band. The
/// vendor command characteristic (`ChileafGATT.commandDoNotWrite`) accepts shutdown and factory
/// reset, so a test in ChileafKit fails if this file ever calls `writeValue`.
///
/// All CoreBluetooth work and all mutable state live on `queue`.
final class ArmbandHeartSource: NSObject, HeartSource, @unchecked Sendable {
    static let deviceIdKey = "armbandPeripheralId"
    /// CoreBluetooth state restoration: if iOS kills the app while connected, a later
    /// notification from the band relaunches it in the background.
    private static let restoreIdentifier = "com.personalscience.barolog.central"
    private static let log = Logger(subsystem: "com.personalscience.barolog", category: "armband")
    private static let heartRate = CBUUID(string: ChileafGATT.heartRateService)
    private static let services = [ChileafGATT.heartRateService, ChileafGATT.batteryService,
                                   ChileafGATT.deviceInformationService, ChileafGATT.vendorService].map(CBUUID.init(string:))
    /// Streamed only while motion is wanted (`setMotionStreaming`), to spare the band's battery.
    private static let motionCharacteristics = [ChileafGATT.vendorFrames, ChileafGATT.ppg].map(CBUUID.init(string:))

    let capabilities = SensorCapabilities(ecg: false, placement: .arm, optical: true)

    private let queue = DispatchQueue(label: "com.personalscience.barolog.armband")
    private let clock: any WallClock
    private let defaults: UserDefaults
    private let continuation = Mutex<AsyncStream<SensorEvent>.Continuation?>(nil)
    private var central: CBCentralManager!
    // Queue-confined state.
    private var peripheral: CBPeripheral?
    private var translator = ArmbandTranslator()
    private var motionWanted = false
    private var motionCharacteristicsFound: [CBCharacteristic] = []
    /// The band `forgetDevice` dropped: its disconnect is expected, so it is not reported.
    private var forgotten: UUID?
    /// The band dropped for HR silence: its disconnect was already reported.
    private var silenced: UUID?
    private var heartRateCharacteristic: CBCharacteristic?
    private var watchdog = HeartRateWatchdog()
    /// Checks for HR silence while connected. A timer, not a ride on notifications, because a
    /// stall leaves no notifications to ride on (straplog-ydg.6).
    private var watchdogTimer: DispatchSourceTimer?

    init(clock: any WallClock = SystemClock(), defaults: UserDefaults = .standard) {
        self.clock = clock
        self.defaults = defaults
        super.init()
        // Created here, before `didFinishLaunching` returns, as restoration requires.
        central = CBCentralManager(delegate: self, queue: queue,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreIdentifier])
    }

    /// One consumer for the app's lifetime; calling again replaces the previous stream.
    func events() -> AsyncStream<SensorEvent> {
        let (stream, cont) = AsyncStream.makeStream(of: SensorEvent.self)
        continuation.withLock { $0?.finish(); $0 = cont }
        queue.async { if self.central.state == .poweredOn { self.connect() } }
        return stream
    }

    func setMotionStreaming(_ on: Bool) {
        queue.async {
            guard on != self.motionWanted else { return }
            self.motionWanted = on
            self.applyMotionSubscriptions()
        }
    }

    func forgetDevice() {
        queue.async {
            self.defaults.removeObject(forKey: Self.deviceIdKey)
            if let p = self.peripheral {
                self.forgotten = p.identifier
                self.stopWatchdog()
                self.central.cancelPeripheralConnection(p)
                self.peripheral = nil
            }
            self.connect()
        }
    }

    // MARK: Connection (on `queue`)

    /// The remembered band, else one already connected to this phone (the BaroShift app may
    /// hold it; iOS shares a connection between apps), else a scan for the first `CL837`.
    private func connect() {
        if let p = peripheral, p.state == .connected || p.state == .connecting { return }
        if let id = defaults.string(forKey: Self.deviceIdKey).flatMap(UUID.init(uuidString:)),
           let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            attach(p)
            return
        }
        if let p = central.retrieveConnectedPeripherals(withServices: [Self.heartRate])
            .first(where: { $0.name?.hasPrefix(ChileafGATT.namePrefix) == true }) {
            Self.log.notice("band already connected to this phone; sharing it")
            remember(p)
            attach(p)
            return
        }
        guard !central.isScanning else { return }
        central.scanForPeripherals(withServices: [Self.heartRate])
    }

    private func remember(_ p: CBPeripheral) {
        defaults.set(p.identifier.uuidString, forKey: Self.deviceIdKey)
    }

    /// A pending connect never times out, so this also waits out a band that is off the arm.
    private func attach(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        if p.state == .connected { didConnect(p) } else { central.connect(p) }
    }

    private func didConnect(_ p: CBPeripheral) {
        Self.log.notice("connected \(p.identifier, privacy: .public)")
        translator.connected()
        motionCharacteristicsFound = []
        heartRateCharacteristic = nil
        emit(.connected(deviceId: p.name ?? p.identifier.uuidString, firmware: nil))
        p.discoverServices(Self.services)
        startWatchdog()
    }

    // MARK: HR-silence watchdog (on `queue`)

    private func startWatchdog() {
        stopWatchdog()
        watchdog.started(atMs: clock.nowMs())
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
        timer.setEventHandler { [weak self] in self?.checkWatchdog() }
        timer.resume()
        watchdogTimer = timer
    }

    private func stopWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
        watchdog.reset()
    }

    private func checkWatchdog() {
        guard let p = peripheral, p.state == .connected else { return }
        switch watchdog.check(atMs: clock.nowMs()) {
        case .none:
            break
        case .resubscribe:
            if let c = heartRateCharacteristic {
                Self.log.notice("HR silent: resubscribing")
                p.setNotifyValue(false, for: c)
                p.setNotifyValue(true, for: c)
            } else {
                Self.log.notice("HR silent, never subscribed: rediscovering services")
                p.discoverServices(Self.services)
            }
        case .reconnect:
            Self.log.notice("HR still silent: reconnecting")
            stopWatchdog()
            emit(translator.flush())
            emit(.disconnected(reason: "HR silent"))
            silenced = p.identifier
            central.cancelPeripheralConnection(p)
        }
    }

    private func applyMotionSubscriptions() {
        guard let p = peripheral, p.state == .connected else { return }
        for c in motionCharacteristicsFound { p.setNotifyValue(motionWanted, for: c) }
    }

    private func emit(_ payload: SensorEvent.Payload) {
        emit([SensorEvent(atMs: clock.nowMs(), payload)])
    }

    private func emit(_ events: [SensorEvent]) {
        continuation.withLock { cont in for e in events { cont?.yield(e) } }
    }
}

extension ArmbandHeartSource: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            emit(.bluetooth(poweredOn: true))
            if let p = peripheral { attach(p) } else { connect() }
        case .poweredOff:
            stopWatchdog()
            emit(translator.flush())
            emit(.bluetooth(poweredOn: false))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard let p = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first else { return }
        peripheral = p
        p.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? p.name
        guard name?.hasPrefix(ChileafGATT.namePrefix) == true else { return }
        central.stopScan()
        remember(p)
        attach(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        didConnect(p)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        Self.log.notice("connect failed: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        emit(.disconnected(reason: "connect failed: \(error?.localizedDescription ?? "unknown")"))
        if p.identifier == peripheral?.identifier { central.connect(p) }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        Self.log.notice("disconnected: \(error?.localizedDescription ?? "no error", privacy: .public)")
        stopWatchdog()
        emit(translator.flush())
        if forgotten == p.identifier {
            forgotten = nil
            return
        }
        if silenced == p.identifier {
            silenced = nil
        } else {
            emit(.disconnected(reason: error?.localizedDescription))
        }
        // Reconnect whenever the band comes back in range or onto the arm.
        if p.identifier == peripheral?.identifier { central.connect(p) }
    }
}

extension ArmbandHeartSource: CBPeripheralDelegate {
    /// The band's GATT table changed under us (another app's command can do this); iOS drops the
    /// invalidated services' subscriptions silently, so rediscover and resubscribe.
    func peripheral(_ p: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        let uuids = invalidatedServices.map(\.uuid)
        Self.log.notice("services modified: \(uuids.map(\.uuidString).joined(separator: ","), privacy: .public)")
        motionCharacteristicsFound.removeAll { c in uuids.contains { $0 == c.service?.uuid } }
        if uuids.contains(Self.heartRate) { heartRateCharacteristic = nil }
        p.discoverServices(uuids.isEmpty ? Self.services : uuids)
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor c: CBCharacteristic, error: Error?) {
        if let error {
            Self.log.notice("notify \(c.uuid.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        } else {
            Self.log.debug("notify \(c.uuid.uuidString, privacy: .public) = \(c.isNotifying)")
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        if let error { Self.log.notice("service discovery failed: \(error.localizedDescription, privacy: .public)") }
        for service in p.services ?? [] { p.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            switch c.uuid.uuidString {
            case ChileafGATT.heartRateMeasurement:
                heartRateCharacteristic = c
                p.setNotifyValue(true, for: c)
                watchdog.started(atMs: clock.nowMs())
            case ChileafGATT.batteryLevel:
                p.readValue(for: c)
                if c.properties.contains(.notify) { p.setNotifyValue(true, for: c) }
            case ChileafGATT.firmwareRevision, ChileafGATT.serialNumber:
                p.readValue(for: c)
            case _ where Self.motionCharacteristics.contains(c.uuid):
                motionCharacteristicsFound.removeAll { $0.uuid == c.uuid }
                motionCharacteristicsFound.append(c)
                if motionWanted { p.setNotifyValue(true, for: c) }
            default:
                break
            }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        if let error {
            Self.log.notice("value \(c.uuid.uuidString, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let data = c.value else { return }
        let bytes = [UInt8](data)
        let now = clock.nowMs()
        switch c.uuid.uuidString {
        case ChileafGATT.heartRateMeasurement:
            watchdog.received(atMs: now)
            emit(translator.heartRate(bytes, atMs: now))
        case ChileafGATT.vendorFrames:
            emit(translator.vendorFrame(bytes, atMs: now))
        case ChileafGATT.ppg:
            emit(translator.ppgPacket(bytes, atMs: now))
        case ChileafGATT.batteryLevel:
            if let percent = bytes.first { emit(.battery(percent: Int(percent))) }
        case ChileafGATT.firmwareRevision:
            emit(.firmware(String(decoding: bytes, as: UTF8.self)))
        case ChileafGATT.serialNumber:
            emit(.serialNumber(String(decoding: bytes, as: UTF8.self)))
        default:
            break
        }
    }
}
