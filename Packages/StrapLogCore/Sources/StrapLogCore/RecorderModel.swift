import Foundation
import GRDB
import Observation

/// The app's view model: forwards sensor events to the `RecordingSession` and keeps the
/// state the screens display. User actions never throw; failures land in `errorMessage`.
@MainActor
@Observable
public final class RecorderModel {
    public private(set) var link = LinkStatus.searching
    public private(set) var battery: Int?
    public private(set) var heartRate: Int?
    public private(set) var contact: Bool?
    /// The recording being written, or nil when idle.
    public private(set) var activeRecording: Recording?
    public private(set) var beatCount = 0
    /// Receive time of the latest HR notification while recording.
    public private(set) var lastHeardAtMs: Int64?
    /// Longest silence between HR notifications in the active recording.
    public private(set) var longestGapMs: Int64 = 0
    public private(set) var recordings: [RecordingSummary] = []
    public private(set) var lastSnapshot: URL?
    public private(set) var errorMessage: String?

    public var isRecording: Bool { activeRecording != nil }

    private let session: RecordingSession
    private let database: StrapLogDatabase
    private let snapshotDirectory: URL

    public init(database: StrapLogDatabase, snapshotDirectory: URL, clock: any WallClock = SystemClock()) {
        self.database = database
        self.snapshotDirectory = snapshotDirectory
        self.session = RecordingSession(database: database, clock: clock)
    }

    /// Call once at launch, before `consume`: reattaches to an unfinished recording.
    public func launch() async {
        await perform {
            if let id = try await session.resumeIfOpen() { try loadActive(id) }
            try refreshRecordings()
        }
    }

    /// Feeds `source` into the session until it finishes. Runs for the app's lifetime.
    public func consume(_ source: some HeartSource) async {
        for await event in source.events() {
            await perform { try await session.ingest(event) }
            apply(event)
        }
    }

    public func start(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        await perform {
            let id = try await session.start(name: trimmed)
            try loadActive(id)
            try refreshRecordings()
        }
    }

    public func stop() async {
        await perform {
            let rec = try await session.stop(snapshotInto: snapshotDirectory)
            lastSnapshot = snapshotDirectory.appendingPathComponent(Snapshot.fileName(for: rec))
            activeRecording = nil
            try refreshRecordings()
        }
    }

    /// `a`, `b`, `c`, `end`, or free text.
    public func marker(_ note: String) async {
        await perform { try await session.marker(note) }
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: Private

    private func apply(_ event: SensorEvent) {
        switch event.payload {
        case .heartRate(let bpm, let contact, let rr1024):
            heartRate = bpm
            self.contact = contact
            guard isRecording else { return }
            if let last = lastHeardAtMs { longestGapMs = max(longestGapMs, event.atMs - last) }
            lastHeardAtMs = event.atMs
            beatCount += rr1024.count
        case .connected(let deviceId, _):
            link = .connected(deviceId: deviceId)
        case .disconnected:
            link = .disconnected
            heartRate = nil
        case .battery(let percent):
            battery = percent
        case .bluetooth(let poweredOn):
            if !poweredOn { link = .bluetoothOff; heartRate = nil }
            else if link == .bluetoothOff { link = .searching }
        }
    }

    private func loadActive(_ id: Int64) throws {
        let (rec, beats, lastHeard) = try database.writer.read { db in
            (try Recording.fetchOne(db, key: id),
             try Beat.filter(sql: "recording_id = ?", arguments: [id]).fetchCount(db),
             try Int64.fetchOne(db, sql: "SELECT MAX(received_at_ms) FROM notification WHERE recording_id = ?",
                                arguments: [id]))
        }
        activeRecording = rec
        beatCount = beats
        lastHeardAtMs = lastHeard
        longestGapMs = 0
    }

    private func refreshRecordings() throws {
        recordings = try database.writer.read { try RecordingSummary.all($0) }
    }

    private func perform(_ body: () async throws -> Void) async {
        do { try await body() } catch { errorMessage = String(describing: error) }
    }
}
