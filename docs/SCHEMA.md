# Schema (v2)

Source of truth: `Schema.migrations` in `Packages/StrapLogCore/Sources/StrapLogCore/Schema.swift`. Each `sql` block below is one migration, verbatim and in order; `SchemaTests.docsMatch` fails if they drift.

Times are **Unix epoch ms UTC**; `tz_offset_s` is the local offset at start, stored per recording. Local wall-clock = `ms/1000 + tz_offset_s`.

```sql
CREATE TABLE meta(
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);
CREATE TABLE recording(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER,
  tz_offset_s INTEGER NOT NULL,
  device_id TEXT,
  firmware TEXT,
  battery_start INTEGER,
  battery_end INTEGER,
  notes TEXT
);
CREATE TABLE notification(
  id INTEGER PRIMARY KEY,
  recording_id INTEGER NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
  received_at_ms INTEGER NOT NULL,
  hr_bpm INTEGER NOT NULL,
  contact INTEGER,
  n_rr INTEGER NOT NULL
);
CREATE INDEX notification_by_recording ON notification(recording_id, received_at_ms);
CREATE TABLE beat(
  id INTEGER PRIMARY KEY,
  recording_id INTEGER NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
  notification_id INTEGER NOT NULL REFERENCES notification(id) ON DELETE CASCADE,
  idx INTEGER NOT NULL,
  rr_1024 INTEGER NOT NULL,
  rr_ms REAL NOT NULL,
  t_end_ms_est INTEGER NOT NULL,
  UNIQUE(notification_id, idx)
);
CREATE INDEX beat_by_recording ON beat(recording_id, id);
CREATE TABLE event(
  id INTEGER PRIMARY KEY,
  recording_id INTEGER NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
  at_ms INTEGER NOT NULL,
  kind TEXT NOT NULL,
  note TEXT
);
CREATE INDEX event_by_recording ON event(recording_id, at_ms);
CREATE TABLE motion(
  recording_id INTEGER NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
  second_ms INTEGER NOT NULL,
  rms_mg REAL NOT NULL,
  gx_mg REAL NOT NULL,
  gy_mg REAL NOT NULL,
  gz_mg REAL NOT NULL,
  n INTEGER NOT NULL,
  PRIMARY KEY(recording_id, second_ms)
);
INSERT INTO meta(key, value) VALUES ('format', 'straplog'), ('schema_version', '1');
```

### v2: `motion` without rowid (Phase 6)

`motion` becomes a `WITHOUT ROWID` table, so its primary key is the table itself: no rowid and no separate key index. With whole-mg values (SQLite stores integral `REAL`s as small integers), an 8 h night adds ~0.7 MB rather than ~1.2 MB (`MotionSessionTests.nightlySize`). v1 never wrote `motion`, so dropping it loses nothing.

```sql
DROP TABLE motion;
CREATE TABLE motion(
  recording_id INTEGER NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
  second_ms INTEGER NOT NULL,
  rms_mg REAL NOT NULL,
  gx_mg REAL NOT NULL,
  gy_mg REAL NOT NULL,
  gz_mg REAL NOT NULL,
  n INTEGER NOT NULL,
  PRIMARY KEY(recording_id, second_ms)
) WITHOUT ROWID;
UPDATE meta SET value = '2' WHERE key = 'schema_version';
```

## Columns that need explaining

- `beat.rr_1024`: RR as sent by the H10, in 1/1024 s; canonical. `rr_ms = rr_1024 * 1000 / 1024` (exact in floating point).
- `beat.t_end_ms_est = received_at_ms − round(Σ later rr_1024 in the same notification × 1000/1024)`. The H10 sends no beat timestamps, so this is an estimate anchored on phone receipt.
- `beat.idx`: position within the notification, oldest first. `notification.n_rr == count(beat)` always.
- `notification.contact`: 1/0, NULL when the sensor does not report skin contact.
- `recording.ended_at_ms` NULL ⇒ unfinished. A relaunch reattaches to the latest such recording (`relaunch` event) rather than starting a new one; `start` refuses while one exists. If its last event or notification is older than 6 h (`RecordingSession.defaultStaleAfterMs`), the relaunch instead closes it at that last activity with a `stop` noted `stale`.
- `recording.device_id`/`firmware`: first values seen (`firmware` arrives over DIS a few seconds after connect). The strap's serial number is shown in the app but not stored. `battery_start`: last reading before or at start; `battery_end`: latest reading.
- `event.kind` ∈ `start stop marker connect disconnect relaunch ble_off ble_on snapshot pacer_start pacer_stop low_battery foreground background` (`EventKind`). Markers carry the label (`a`, `b`, `c`, `end`, free text) in `note`; `connect` carries the device id; `disconnect` the reason, if any; `snapshot` the file name; `low_battery` the strap's percent (once per recording, at ≤ 10 %). `foreground`/`background` are scene-phase changes while recording (none during a background-only restoration launch). `snapshot` is written on Stop, every 30 min of recording, and on each move to the background.
- `connect`/`disconnect` are logged on transitions only. A recording started while connected opens with `start, connect`.
- `meta`: `format = straplog`, `schema_version = 2`, so loaders can recognise the file.
- `motion`: one row per wall-clock second of accelerometer data (25 Hz, 8 G), written only while recording. `second_ms` is the second's start (epoch ms UTC, a multiple of 1000). `rms_mg` is the RMS of |a| − 1000 mg over the second: ~0 when still, larger with movement. `gx/gy/gz_mg` are the mean acceleration per axis, i.e. the gravity vector, so posture. `n` is the sample count (≈ 25). All are whole mg. Sample times are placed back from the phone's receipt by the strap's own clock deltas (`MotionReducer.timesMs`), clamped to be non-decreasing. A second split by a relaunch is merged as if reduced whole (`MotionSecond.merged`). The partial last second is written on Stop.

## Files

- Live: `Application Support/StrapLog/live.sqlite`, WAL (`DatabasePool`), one transaction per notification or event.
- Export: `<YYMMDD-HHMM>-<name>.sqlite` (`Snapshot.fileName`, local start time, name sanitised) in the iCloud container's `Documents/` (iCloud Drive → StrapLog; on the Mac `~/Library/Mobile Documents/iCloud~com~personalscience~straplog/Documents/`), or `Documents/StrapLog/` (On My iPhone) when iCloud is unavailable (`ExportFolder`). `Snapshot.write` runs `VACUUM INTO` a temp file outside the export folder, sets `journal_mode = DELETE`, then atomically replaces the target under `NSFileCoordinator`, so readers never see a partial file or create `-wal`/`-shm`. The snapshot holds **only its own recording** (the others are deleted from the copy, then it is vacuumed), keeping its live-DB `recording.id`. Deleting a recording in the app (Home → swipe) removes its rows and its snapshot file from both export folders, file-coordinated so iCloud Drive drops it too; the recording being written cannot be deleted.

## Invariants (`DBInvariants`)

`n_rr == count(beat)` per notification · beat and notification share `recording_id` · `rr_ms == rr_1024 * 1000/1024` · `received_at_ms` non-decreasing per recording · exactly one `start` per recording, and one `stop` iff `ended_at_ms` is set.
