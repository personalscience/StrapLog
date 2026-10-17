import Foundation

/// Where snapshots go: the app's iCloud Drive folder when available, else a local folder.
/// Resolving iCloud can block, so it runs on this actor, never the main thread. A found
/// iCloud folder is kept for the process; a miss (signed out, iCloud Drive off) is retried.
public actor ExportFolder {
    private let local: URL
    private let cloud: (@Sendable () -> URL?)?
    private var resolvedCloud: URL?

    /// `cloud` returns the iCloud folder or nil; omit it for a local-only folder.
    public init(local: URL, cloud: (@Sendable () -> URL?)? = nil) {
        self.local = local
        self.cloud = cloud
    }

    public func url() -> URL {
        if let resolvedCloud { return resolvedCloud }
        resolvedCloud = cloud?()
        return resolvedCloud ?? local
    }

    /// Every folder a snapshot may be in: iCloud (if available) and the local fallback,
    /// since a snapshot lands locally whenever iCloud was unavailable at the time.
    public func all() -> [URL] {
        let current = url()
        return current == local ? [local] : [current, local]
    }
}
