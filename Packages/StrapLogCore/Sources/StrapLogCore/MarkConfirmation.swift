/// Tells the Watch when a marker it sent has reached the phone: the phone's status shows a higher
/// marker count while a send is outstanding. Markers added on the phone alone never confirm.
public struct MarkConfirmation: Sendable {
    private var seenCount = 0
    private var outstanding = 0

    public init() {}

    /// A marker left the Watch while the status showed `markerCount`.
    public mutating func sent(markerCount: Int) {
        if outstanding == 0 { seenCount = markerCount }
        outstanding += 1
    }

    /// Whether `status` confirms a sent marker. `status` nil means idle, so nothing can land.
    public mutating func landed(_ status: LiveStatus?) -> Bool {
        guard outstanding > 0 else { return false }
        guard let status else {
            outstanding = 0
            return false
        }
        let landed = status.markerCount - seenCount
        guard landed > 0 else { return false }
        seenCount = status.markerCount
        outstanding = max(0, outstanding - landed)
        return true
    }
}
