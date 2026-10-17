/// Sends each `LiveStatus` to several displays (the Live Activity and the Watch), so they share
/// one `LiveStatusThrottle` in `RecorderModel`.
@MainActor
public final class LiveStatusFanOut: LiveStatusDisplay {
    private let displays: [any LiveStatusDisplay]

    public init(_ displays: [any LiveStatusDisplay]) {
        self.displays = displays
    }

    public func show(_ status: LiveStatus?) {
        for display in displays { display.show(status) }
    }
}
