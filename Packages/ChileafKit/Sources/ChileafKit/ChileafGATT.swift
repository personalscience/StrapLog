/// The band's GATT table as read on 2026-11-03 (`~/dev/baroshift/notes/intake/2026-11-03-cl837-gatt-probe.txt`).
/// Strings, so the package stays free of CoreBluetooth; the app wraps them in `CBUUID`.
public enum ChileafGATT {
    /// Advertised by the band, and the name the app matches on: `CL837-0919897`.
    public static let namePrefix = "CL837"

    public static let heartRateService = "180D"
    /// Standard Heart Rate Measurement: HR and RR (`HeartRateMeasurement`).
    public static let heartRateMeasurement = "2A37"
    public static let batteryService = "180F"
    public static let batteryLevel = "2A19"
    public static let deviceInformationService = "180A"
    public static let manufacturerName = "2A29"
    public static let modelNumber = "2A24"
    public static let serialNumber = "2A25"
    public static let firmwareRevision = "2A26"

    public static let vendorService = "AAE28F00-71B5-42A1-8C3C-F9CF6AC969D0"
    /// Framed vendor data, about 52/s: mostly accelerometer (`VendorFrame`).
    public static let vendorFrames = "AAE28F01-71B5-42A1-8C3C-F9CF6AC969D0"
    /// Raw PPG, about 32/s (`PpgPacket`).
    public static let ppg = "AAE21542-71B5-42A1-8C3C-F9CF6AC969D0"
    /// The band's command characteristic. Never written: Chileaf's SDK sends shutdown and
    /// factory reset here. Listed only so code and tests can name what must stay untouched.
    public static let commandDoNotWrite = "AAE28F02-71B5-42A1-8C3C-F9CF6AC969D0"
}
