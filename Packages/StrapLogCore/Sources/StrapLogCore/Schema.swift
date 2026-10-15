import GRDB

/// Database migrations. Each is an SQL block in `docs/SCHEMA.md`, verbatim and in order
/// (a test enforces it).
public enum Schema {
    public static let v1 = """
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
        """

    /// Rebuilds `motion` as `WITHOUT ROWID`: the primary key becomes the table, dropping the
    /// rowid and the separate key index, so a night of motion stays under 1 MB. v1 never wrote
    /// `motion`, so nothing is lost.
    public static let v2 = """
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
        """

    /// Migrations in order; `docs/SCHEMA.md` holds one SQL block per entry.
    public static let migrations = [("v1", v1), ("v2", v2)]

    public static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        for (name, sql) in migrations {
            m.registerMigration(name) { db in try db.execute(sql: sql) }
        }
        return m
    }
}
