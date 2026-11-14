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

    let capabilities = SensorCapabilities(ecg: false, placement: .arm)

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
        translator.connected()
        motionCharacteristicsFound = []
        emit(.connected(deviceId: p.name ?? p.identifier.uuidString, firmware: nil))
        p.discoverServices(Self.services)
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
        emit(.disconnected(reason: "connect failed: \(error?.localizedDescription ?? "unknown")"))
        if p.identifier == peripheral?.identifier { central.connect(p) }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        emit(translator.flush())
        if forgotten == p.identifier {
            forgotten = nil
            return
        }
        emit(.disconnected(reason: error?.localizedDescription))
        // Reconnect whenever the band comes back in range or onto the arm.
        if p.identifier == peripheral?.identifier { central.connect(p) }
    }
}

extension ArmbandHeartSource: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for service in p.services ?? [] { p.discoverCharacteristics(nil, for: service) }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            switch c.uuid.uuidString {
            case ChileafGATT.heartRateMeasurement:
                p.setNotifyValue(true, for: c)
            case ChileafGATT.batteryLevel:
                p.readValue(for: c)
                if c.properties.contains(.notify) { p.setNotifyValue(true, for: c) }
            case ChileafGATT.firmwareRevision, ChileafGATT.serialNumber:
                p.readValue(for: c)
            case _ where Self.motionCharacteristics.contains(c.uuid):
                motionCharacteristicsFound.append(c)
                if motionWanted { p.setNotifyValue(true, for: c) }
            default:
                break
            }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard error == nil, let data = c.value else { return }
        let bytes = [UInt8](data)
        let now = clock.nowMs()
        switch c.uuid.uuidString {
        case ChileafGATT.heartRateMeasurement:
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
