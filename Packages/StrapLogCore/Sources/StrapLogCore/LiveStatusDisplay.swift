/// Where `RecorderModel` sends `LiveStatus`: the app's ActivityKit Live Activity. A protocol so
/// the package stays free of ActivityKit and the model's publishing is testable on macOS.
@MainActor
public protocol LiveStatusDisplay: AnyObject {
    /// `status` nil ends the display: no recording is open.
    func show(_ status: LiveStatus?)
}
