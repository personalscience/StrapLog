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
    /// From the strap's Device Information Service; kept across disconnects.
    public private(set) var firmware: String?
    public private(set) var serialNumber: String?
    public private(set) var heartRate: Int?
    public private(set) var contact: Bool?
    /// The recording being written, or nil when idle.
    public private(set) var activeRecording: Recording?
    public private(set) var beatCount = 0
    /// Receive time of the latest HR notification while recording.
    public private(set) var lastHeardAtMs: Int64?
    /// Longest silence between HR notifications in the active recording.
    public private(set) var longestGapMs: Int64 = 0
    /// Markers of the active recording, oldest first.
    public private(set) var markers: [RecordingEvent] = []
    /// Latest marker in the active recording, so the UI can confirm a tap.
    public var lastMarker: RecordingEvent? { markers.last }
    public var markerCount: Int { markers.count }
    /// HRV windows and RR history for the active recording.
    public private(set) var live = LiveMetrics()
    /// The running breathing pacer, or nil.
    public private(set) var pacer: BreathingPacer?
    public private(set) var recordings: [RecordingSummary] = []
    public private(set) var lastSnapshot: URL?
    /// The recording that just stopped, for Home's summary card; cleared by the next Start.
    public private(set) var lastFinished: RecordingDetail?
    public private(set) var errorMessage: String?
    /// The user's marker bars, one per activity.
    public private(set) var markerPresets: MarkerPresets
    /// Free-text marker notes offered as one-tap suggestions, most recent first.
    public private(set) var recentNotes: [String] = []

    public var isRecording: Bool { activeRecording != nil }

    /// What the Live Activity shows, or nil when idle.
    public var liveStatus: LiveStatus? {
        guard let rec = activeRecording else { return nil }
        let linked = if case .connected = link { true } else { false }
        return LiveStatus(name: rec.name, activity: rec.activity, startedAtMs: rec.startedAtMs, heartRate: heartRate,
                          contact: contact, linked: linked, alpha1: live.latest?.alpha1, rmssd: live.latest?.rmssd,
                          battery: battery, markers: activePreset.markers, markerCount: markerCount,
                          lastMarkerLabel: lastMarker?.label, lastMarkerText: lastMarker?.markerText,
                          lastMarkerAtMs: lastMarker?.atMs)
    }
    /// The active recording's preset: its marker bar and pacer. `other` when idle.
    public var activePreset: ActivityPreset { markerPresets.preset(activeRecording?.activity ?? ActivityPreset.other.id) }

    private let session: RecordingSession
    private let database: StrapLogDatabase
    private let exports: ExportFolder
    private let snapshotEveryMs: Int64
    private let clock: any WallClock
    private let display: (any LiveStatusDisplay)?
    private var throttle: LiveStatusThrottle
    /// Where `markerPresets` is saved.
    private let defaults: UserDefaults
    /// The source being consumed; told to stream motion only while recording.
    private var source: (any HeartSource)?

    /// Default `snapshotEveryMs`: a crash or a dead phone mid-night loses at most 30 min of export.
    public static let defaultSnapshotEveryMs: Int64 = 30 * 60_000
    /// How many `recentNotes` to offer.
    public static let recentNoteLimit = 8

    /// `appVersion` is stamped into every export (`ExportMeta`, `index.json`).
    public init(database: StrapLogDatabase, exports: ExportFolder, clock: any WallClock = SystemClock(),
                snapshotEveryMs: Int64 = RecorderModel.defaultSnapshotEveryMs, appVersion: String = "dev",
                defaults: UserDefaults = .standard, display: (any LiveStatusDisplay)? = nil,
                throttle: LiveStatusThrottle = LiveStatusThrottle()) {
        self.database = database
        self.clock = clock
        self.display = display
        self.throttle = throttle
        self.exports = exports
        self.snapshotEveryMs = snapshotEveryMs
        self.defaults = defaults
        let markerPresets = MarkerPresets.load(from: defaults)
        self.markerPresets = markerPresets
        self.session = RecordingSession(database: database, clock: clock, appVersion: appVersion,
                                        markerPresets: markerPresets)
    }

    /// Call once at launch, before `consume`: reattaches to an unfinished recording.
    public func launch() async {
        await perform {
            if let id = try await session.resumeIfOpen() { try loadActive(id) }
            try refreshRecordings()
            try refreshRecentNotes()
        }
        publishStatus()
    }

    /// Feeds `source` into the session until it finishes. Runs for the app's lifetime.
    public func consume(_ source: some HeartSource) async {
        self.source = source
        source.setMotionStreaming(isRecording)
        for await event in source.events() {
            await perform {
                try await session.ingest(event)
                guard case .heartRate = event.payload,
                      let url = try await session.snapshotIfDue(into: exports.url(), everyMs: snapshotEveryMs)
                else { return }
                lastSnapshot = url
            }
            apply(event)
            await perform {
                if let resting = try await session.beginRestingIfDue() { markers.append(resting) }
            }
            if let reason = await session.autoStopDue() { await finish(because: reason) }
            publishStatus()
        }
    }

    /// An empty or blank `name` becomes `activity.defaultName`. `plan` applies to `overnight` activities.
    public func start(_ activity: ActivityPreset = .other, name: String,
                      plan: OvernightPlan = OvernightPlan(wakeAtMs: nil)) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        await perform {
            let id = try await session.start(activity, name: trimmed, plan: plan)
            source?.setMotionStreaming(true)
            lastFinished = nil
            try loadActive(id)
            try refreshRecordings()
        }
        publishStatus()
    }

    public func stop() async {
        await finish(because: nil)
    }

    /// The active recording's plan, nil unless it is overnight.
    public var overnightPlan: OvernightPlan? {
        guard let rec = activeRecording, activePreset.overnight else { return nil }
        return OvernightPlan(contextJSON: rec.context)
    }

    /// A label from `activePreset.markers`, free text, or both; blank text is dropped.
    public func marker(label: String? = nil, note: String? = nil) async {
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = note?.isEmpty == false ? note : nil
        guard label != nil || text != nil else { return }
        await perform {
            markers.append(try await session.marker(label: label, note: text))
            if text != nil { try refreshRecentNotes() }
        }
        publishStatus()
    }

    /// Replaces `activity`'s marker bar (`MarkerPresets.setMarkers`); takes effect at once,
    /// in the active recording too.
    public func setMarkers(_ labels: [String], for activity: ActivityPreset) async {
        var edited = markerPresets
        edited.setMarkers(labels, for: activity.id)
        await save(edited)
    }

    /// Restores `activity`'s built-in marker bar.
    public func resetMarkers(for activity: ActivityPreset) async {
        var edited = markerPresets
        edited.reset(activity.id)
        await save(edited)
    }

    /// Starts the pacer at `breathsPerMinute` (within `BreathingPacer.rates`), replacing a running one.
    public func startPacer(breathsPerMinute: Double) async {
        await stopPacer()
        await perform {
            pacer = try await session.startPacer(breathsPerMinute: breathsPerMinute)
        }
    }

    public func stopPacer() async {
        guard pacer != nil else { return }
        pacer = nil
        await perform { try await session.stopPacer() }
    }

    /// Scene phase changes. Going to the background while recording also exports a snapshot,
    /// since the app may not come back to the foreground before it is killed.
    public func appPhase(_ phase: AppPhase) async {
        await perform {
            try await session.appPhase(phase)
            guard phase == .background, isRecording else { return }
            lastSnapshot = try await session.snapshot(into: exports.url())
        }
    }

    /// Deletes a finished recording and its snapshot file from every export folder, and
    /// drops it from each folder's `index.json`.
    public func delete(_ summary: RecordingSummary) async {
        await perform {
            let rec = try await session.delete(summary.id)
            let name = Snapshot.fileName(for: rec)
            for directory in await exports.all() {
                let url = directory.appendingPathComponent(name)
                try CoordinatedFile.remove(at: url)
                try await session.reindex(directory)
                if lastSnapshot?.standardizedFileURL == url.standardizedFileURL { lastSnapshot = nil }
            }
            try refreshRecordings()
            try refreshRecentNotes()
        }
    }

    /// A recording with its summary, markers and chart series; nil (with `errorMessage` set
    /// on failure) if it cannot be read. The analysis runs on the database's reader, off the main actor.
    public func detail(_ id: Int64) async -> RecordingDetail? {
        var detail: RecordingDetail?
        await perform { detail = try await database.writer.read { db in try RecordingDetail.load(id, db: db) } }
        return detail
    }

    /// Saves `edit` to a finished recording and exports it again: its snapshot file is renamed
    /// with it (the old name is removed from every export folder) and every index is refreshed.
    /// Returns the reloaded detail, or nil on failure.
    public func edit(_ id: Int64, _ edit: RecordingEdit) async -> RecordingDetail? {
        var saved = false
        await perform {
            let (before, after) = try await session.edit(id, edit)
            let oldName = Snapshot.fileName(for: before)
            if oldName != Snapshot.fileName(for: after) {
                for directory in await exports.all() {
                    try CoordinatedFile.remove(at: directory.appendingPathComponent(oldName))
                }
            }
            try await writeExport(id)
            try refreshRecordings()
            saved = true
        }
        guard saved else { return nil }
        let reloaded = await detail(id)
        if lastFinished?.id == id { lastFinished = reloaded }
        return reloaded
    }

    /// Writes a finished recording's snapshot again into the current export folder.
    public func reexport(_ id: Int64) async {
        await perform { try await writeExport(id) }
    }

    /// The recording's snapshot file in the current export folder, if it is there.
    public func exportURL(for recording: Recording) async -> URL? {
        let url = await exports.url().appendingPathComponent(Snapshot.fileName(for: recording))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func dismissError() {
        errorMessage = nil
    }

    // MARK: Commands (Shortcuts and Siri)

    /// Starts `activity` unless a recording is open, which keeps running: a Sleep Focus
    /// automation firing twice must not end the night.
    public func startUnlessRecording(_ activity: ActivityPreset, name: String = "",
                                     plan: OvernightPlan) async -> CommandOutcome {
        if let rec = activeRecording { return .alreadyRecording(rec) }
        await start(activity, name: name, plan: plan)
        return activeRecording.map(CommandOutcome.done) ?? failure()
    }

    public func stopIfRecording() async -> CommandOutcome {
        guard let rec = activeRecording else { return .notRecording }
        await stop()
        return isRecording ? failure() : .done(rec)
    }

    /// `text` is a label when it is one of `activePreset.markers`, otherwise a note.
    public func markIfRecording(_ text: String) async -> CommandOutcome {
        guard let rec = activeRecording else { return .notRecording }
        let count = markerCount
        if activePreset.markers.contains(text) { await marker(label: text) } else { await marker(note: text) }
        return markerCount > count ? .done(rec) : failure()
    }

    private func failure() -> CommandOutcome {
        .failed(errorMessage ?? "Nothing happened.")
    }

    // MARK: Private

    /// Stops and exports the recording, by the user (`reason` nil) or by itself.
    private func finish(because reason: AutoStop?) async {
        await stopPacer()
        await perform {
            let directory = await exports.url()
            let rec = try await session.stop(because: reason, snapshotInto: directory)
            source?.setMotionStreaming(false)
            lastSnapshot = directory.appendingPathComponent(Snapshot.fileName(for: rec))
            activeRecording = nil
            markers = []
            live = LiveMetrics()
            try refreshRecordings()
            if let id = rec.id { lastFinished = try await database.writer.read { db in try RecordingDetail.load(id, db: db) } }
        }
        publishStatus()
    }

    /// `reexport` into the current folder, `lastSnapshot` pointing at it, other folders reindexed.
    private func writeExport(_ id: Int64) async throws {
        let current = await exports.url()
        lastSnapshot = try await session.reexport(id, into: current)
        for directory in await exports.all() where directory.standardizedFileURL != current.standardizedFileURL {
            try await session.reindex(directory)
        }
    }

    private func apply(_ event: SensorEvent) {
        switch event.payload {
        case .heartRate(let bpm, let contact, let rr1024):
            heartRate = bpm
            self.contact = contact
            guard isRecording else { return }
            if let last = lastHeardAtMs { longestGapMs = max(longestGapMs, event.atMs - last) }
            lastHeardAtMs = event.atMs
            beatCount += rr1024.count
            for (rr, end) in zip(rr1024, BeatTiming.endTimesMs(receivedAtMs: event.atMs, rr1024: rr1024)) {
                live.add(tEndMs: end, rrMs: BeatTiming.ms(fromRR1024: rr))
            }
        case .connected(let deviceId, let firmware):
            link = .connected(deviceId: deviceId)
            if let firmware { self.firmware = firmware }
        case .disconnected:
            link = .disconnected
            heartRate = nil
        case .battery(let percent):
            battery = percent
        case .firmware(let version):
            firmware = version
        case .serialNumber(let serial):
            serialNumber = serial
        case .bluetooth(let poweredOn):
            if !poweredOn { link = .bluetoothOff; heartRate = nil }
            else if link == .bluetoothOff { link = .searching }
        case .motion:
            break
        }
    }

    private func loadActive(_ id: Int64) throws {
        let (rec, beats, lastHeard, markers) = try database.writer.read { db in
            (try Recording.fetchOne(db, key: id),
             try Beat.filter(sql: "recording_id = ?", arguments: [id]).order(sql: "id").fetchAll(db),
             try Int64.fetchOne(db, sql: "SELECT MAX(received_at_ms) FROM notification WHERE recording_id = ?",
                                arguments: [id]),
             try RecordingEvent.fetchAll(db, sql: "SELECT * FROM event WHERE recording_id = ? AND kind = 'marker' ORDER BY id",
                                         arguments: [id]))
        }
        activeRecording = rec
        beatCount = beats.count
        live = LiveMetrics()
        for beat in beats { live.add(beat) }
        pacer = nil
        lastHeardAtMs = lastHeard
        self.markers = markers
        longestGapMs = 0
    }

    private func refreshRecordings() throws {
        recordings = try database.writer.read { try RecordingSummary.all($0) }
    }

    private func refreshRecentNotes() throws {
        recentNotes = try database.writer.read { try RecordingEvent.recentNotes($0, limit: Self.recentNoteLimit) }
    }

    private func save(_ edited: MarkerPresets) async {
        await perform {
            try edited.save(to: defaults)
            markerPresets = edited
            await session.use(edited)
        }
        publishStatus()
    }

    private func publishStatus() {
        guard let display else { return }
        let status = liveStatus
        if throttle.admit(status, atMs: clock.nowMs()) { display.show(status) }
    }

    private func perform(_ body: () async throws -> Void) async {
        do { try await body() } catch { errorMessage = String(describing: error) }
    }
}
