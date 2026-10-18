import CoreBluetooth
import StrapLogCore

/// Listens for the strap's HR broadcasts (`StrapBroadcast`) without connecting, so the strap's
/// two connection slots and the phone's link are untouched, and nothing is paired that would
/// change the Watch's HealthKit HR source. Duplicates are on: each advertisement is a reading.
@MainActor
final class StrapScanner: NSObject {
    /// Each reading from the strap named by `strapId` (any H10 while nil).
    var onReading: ((StrapBroadcast) -> Void)?
    var strapId: String?
    private var central: CBCentralManager?
    private var wanted = false

    /// Creating the manager is what asks for Bluetooth permission, so it waits for the first start.
    func start() {
        wanted = true
        if let central { scanIfReady(central) } else { central = CBCentralManager(delegate: self, queue: nil) }
    }

    func stop() {
        wanted = false
        central?.stopScan()
    }

    private func scanIfReady(_ central: CBCentralManager) {
        guard wanted, central.state == .poweredOn, !central.isScanning else { return }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    private func receive(name: String?, manufacturerData: Data?) {
        guard wanted, StrapBroadcast.isStrap(named: name, strapId: strapId),
              let manufacturerData, let reading = StrapBroadcast(manufacturerData: manufacturerData) else { return }
        onReading?(reading)
    }
}

extension StrapScanner: CBCentralManagerDelegate {
    // The manager runs on the main queue (`queue: nil`). It is not Sendable, so the closure uses
    // the stored one rather than the parameter.
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if let central = self.central { scanIfReady(central) }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        MainActor.assumeIsolated { receive(name: name, manufacturerData: data) }
    }
}
