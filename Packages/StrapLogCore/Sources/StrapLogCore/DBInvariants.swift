import GRDB

/// Structural checks every StrapLog database must pass. Returns human-readable
/// violations (empty means healthy). Reused by session tests now and snapshot checks later.
public enum DBInvariants {
    public static func violations(_ reader: any DatabaseReader) throws -> [String] {
        try reader.read(violations(in:))
    }

    public static func violations(in db: Database) throws -> [String] {
        var out: [String] = []

        for row in try Row.fetchAll(db, sql: """
            SELECT n.id, n.n_rr, COUNT(b.id) AS beats
            FROM notification n LEFT JOIN beat b ON b.notification_id = n.id
            GROUP BY n.id HAVING n.n_rr != COUNT(b.id)
            """) {
            out.append("notification \(row["id"] as Int64): n_rr \(row["n_rr"] as Int) != \(row["beats"] as Int) beats")
        }

        for id in try Int64.fetchAll(db, sql: """
            SELECT b.id FROM beat b JOIN notification n ON n.id = b.notification_id
            WHERE b.recording_id != n.recording_id
            """) {
            out.append("beat \(id): recording_id differs from its notification's")
        }

        for id in try Int64.fetchAll(db, sql: "SELECT id FROM beat WHERE rr_ms != rr_1024 * 1000.0 / 1024") {
            out.append("beat \(id): rr_ms != rr_1024 * 1000 / 1024")
        }

        for id in try Int64.fetchAll(db, sql: """
            SELECT id FROM (
              SELECT id, received_at_ms,
                     LAG(received_at_ms) OVER (PARTITION BY recording_id ORDER BY id) AS prev
              FROM notification)
            WHERE received_at_ms < prev
            """) {
            out.append("notification \(id): received_at_ms goes backwards")
        }

        for row in try Row.fetchAll(db, sql: """
            SELECT r.id, r.ended_at_ms,
                   SUM(e.kind = 'start') AS starts, SUM(e.kind = 'stop') AS stops
            FROM recording r LEFT JOIN event e ON e.recording_id = r.id
            GROUP BY r.id
            """) {
            let id: Int64 = row["id"]
            let starts: Int = row["starts"] ?? 0
            let stops: Int = row["stops"] ?? 0
            let ended = (row["ended_at_ms"] as Int64?) != nil
            if starts != 1 { out.append("recording \(id): \(starts) start events") }
            if stops != (ended ? 1 : 0) { out.append("recording \(id): \(stops) stop events, ended=\(ended)") }
        }

        return out
    }
}
