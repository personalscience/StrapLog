# Schema v1 (DRAFT until Phase 2 lands the migration)

Times are **Unix epoch ms UTC**; `tz_offset_s` is stored per recording. Phase 2 makes this file match the GRDB migration exactly.

```sql
meta(key TEXT PRIMARY KEY, value TEXT);
recording(id INTEGER PRIMARY KEY, name TEXT, started_at_ms INT, ended_at_ms INT, tz_offset_s INT,
          device_id TEXT, firmware TEXT, battery_start INT, battery_end INT, notes TEXT);
notification(id INTEGER PRIMARY KEY, recording_id INT, received_at_ms INT, hr_bpm INT, contact INT, n_rr INT);
beat(id INTEGER PRIMARY KEY, recording_id INT, notification_id INT, idx INT,
     rr_1024 INT, rr_ms REAL, t_end_ms_est INT);
event(id INTEGER PRIMARY KEY, recording_id INT, at_ms INT, kind TEXT, note TEXT);
motion(recording_id INT, second_ms INT, rms_mg REAL, gx_mg REAL, gy_mg REAL, gz_mg REAL, n INT,
       PRIMARY KEY(recording_id, second_ms));
```

- `rr_ms = rr_1024 * 1000 / 1024`.
- `t_end_ms_est = received_at_ms − Σ(later RRs in the same notification)`.
- `event.kind` ∈ `start stop marker connect disconnect relaunch ble_off ble_on snapshot pacer_start pacer_stop low_battery`.
- Live DB: `Application Support/StrapLog/live.sqlite`, WAL, one transaction per notification. Export: `VACUUM INTO Documents/StrapLog/<YYMMDD-HHMM>-<name>.sqlite`.
