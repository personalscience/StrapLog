import Foundation
import Observation
import StrapLogCore

/// The strap's own HR for when the phone has none (`HeartRateSourcePolicy`): scans only while
/// the app is on screen and the phone is gone, and shows HR only (no RR, so no α1). Display
/// only; the phone stays the only recorder.
@MainActor
@Observable
final class StrapHeart {
    private(set) var source: HeartRateSource = .idle
    private(set) var reading: StrapBroadcast?
    @ObservationIgnored private var readAt: Date?
    @ObservationIgnored private var policy = HeartRateSourcePolicy()
    @ObservationIgnored private let scanner = StrapScanner()
    @ObservationIgnored private let phone: PhoneLink
    @ObservationIgnored private var isForeground = false

    /// The last strap id the phone reported, for when the phone is gone.
    static let strapIdKey = "strapId"
    /// A reading older than this shows as searching: the strap is off or out of range.
    static let readingFreshFor: TimeInterval = 5

    init(phone: PhoneLink) {
        self.phone = phone
        scanner.onReading = { [weak self] in self?.receive($0) }
    }

    func setForeground(_ isForeground: Bool) {
        self.isForeground = isForeground
        evaluate()
    }

    /// Re-runs the policy; called on every phone change and the phone's stale tick.
    func evaluate() {
        if let strapId = phone.status?.strapId { UserDefaults.standard.set(strapId, forKey: Self.strapIdKey) }
        let next = policy.update(isForeground: isForeground, isReachable: phone.isReachable, status: phone.status,
                                 receivedAtMs: phone.receivedAt.map(Self.ms), nowMs: Self.ms(.now))
        guard next != source else { return }
        source = next
        if next == .strap {
            scanner.strapId = UserDefaults.standard.string(forKey: Self.strapIdKey)
            scanner.start()
        } else {
            scanner.stop()
            reading = nil
            readAt = nil
        }
    }

    /// The strap reading to show at `now`: nil unless the strap is the source and spoke lately.
    func shownReading(at now: Date) -> StrapBroadcast? {
        guard source == .strap, let readAt, now.timeIntervalSince(readAt) <= Self.readingFreshFor else { return nil }
        return reading
    }

    private func receive(_ reading: StrapBroadcast) {
        self.reading = reading
        readAt = .now
    }

    private static func ms(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }
}
