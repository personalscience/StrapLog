/// What the shared screens call the app and the sensor it records from. Each app target defines
/// `AppBrand.current` in its own `App/` folder, so the shared code never names a product or device.
struct AppBrand: Sendable {
    /// The app's display name, also the folder Files shows its exports in.
    let appName: String
    /// The sensor, lower case, singular: `strap`, `armband`.
    let device: String
    /// Under the device details while nothing is linked: how to make the sensor show up.
    let wearHint: String

    /// The device noun capitalised for headers and buttons: `Strap`.
    var deviceTitle: String { device.prefix(1).uppercased() + device.dropFirst() }
}
