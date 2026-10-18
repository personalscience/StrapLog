# CLAUDE.md — StrapLog

Personal iOS app (sideloaded, team `4RZ2RJUXC8`) that logs per-beat RR intervals from a Polar H10 to crash-safe SQLite, replacing Marco Altini's HRV Logger for Rik's HRV skills (live copies in `~/Documents/Notes/.claude/skills/*`). Built in phases tracked as beads; the plan is `~/.claude/plans/i-d-like-to-make-velvety-wreath.md` (read only the current phase's section).

## Commands

```
xcodegen generate                                   # after any project.yml or file-tree change
(cd Packages/HRVKit && swift test)                  # pure algorithms, macOS, seconds
(cd Packages/StrapLogCore && swift test)            # model, schema, session, macOS
(cd tools/py && uv run pytest)                      # straplog Python package + CLI
xcodebuild test -scheme StrapLog -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/dd
xcodebuild -scheme StrapLog -destination 'generic/platform=iOS' -derivedDataPath build/dd build
```

## Map

| Area | Path | Read first |
|---|---|---|
| Algorithms (RR cleaning, RMSSD, DFA α1) | `Packages/HRVKit` | constants mirror `~/dev/skills/h10-session/.../analyze_h10.py` |
| Domain, GRDB schema, `RecordingSession` | `Packages/StrapLogCore` | `docs/SCHEMA.md` before touching migrations |
| App: Polar adapter, SwiftUI, AppDelegate | `StrapLog/` | `docs/SDK-NOTES.md` before touching `StrapLog/Polar/` |
| Watch app (remote display/controller over WatchConnectivity) | `StrapLogWatch/`, `StrapLog/Watch/` | wire format is `WatchPayload` in Core; the phone stays the only recorder |
| Python reader + `straplog` CLI | `tools/py` | the HRV skills depend on it; keep `straplog.db`'s API stable |
| Tests and fixtures | `*Tests/`, `Tests/fixtures/` | `docs/TESTING.md` |
| Xcode project | `project.yml` | never hand-edit `StrapLog.xcodeproj` |

## Rules that the tree does not tell you

- Only `StrapLog/Polar/` may `import PolarBleSdk`; everything else talks to `HeartSource`. Keeps the SDK swappable for a raw CoreBluetooth client.
- Packages stay macOS-buildable (no UIKit, no SDK) so all logic is testable with `swift test` and no Bluetooth.
- Packages are Swift 6 language mode; the app target is Swift 5 mode with complete strict-concurrency checking, because the SDK's tuple typealiases are not `Sendable`.
- Times in the DB are Unix epoch ms UTC plus `tz_offset_s`. HRV Logger stored local time as UTC; never repeat that.
- Never ship a `-wal`/`-shm` off device: exports are `VACUUM INTO` single-file snapshots.
- No logic in views; one type per file.
- Phase protocol: `bd update <id> --status in_progress` → build with tests → `bd note` + `bd close` → update the plan's Status line → `git add -A` → wait for "commit".

## Vault

- Hub note: `~/Documents/Notes/Sprague2026/Health2026/Fitness/H10 R-R Capture After iOS 27.md`

## Learned

- 2026-10-14: `bd init` also writes AGENTS.md plus `.codex/`, `.cursor/`, `.agents/` scaffolding; removed as unused in this solo repo.
- 2026-10-14: In `async` test functions GRDB's `read`/`write` resolve to the async overloads and need `await`; keep `TestRig` helpers synchronous so tests stay terse.
- 2026-10-14: The injectable clock is `WallClock` (the stdlib owns `Clock`). Feed sessions with `HeartSource.pump(into:)`.
- 2026-10-14: The view model (`RecorderModel`) lives in StrapLogCore, not the app, so its tests run on macOS. Simulator/UI runs use `-replay resting -speed 20 -freshDatabase`. Check device exports with `tools/check_snapshot.sh`.
- 2026-10-14: `git rm` of a directory's last file deletes the directory; XcodeGen then fails on the missing source path.
- 2026-10-15: Recording work starts in `AppDelegate.didFinishLaunching` via `Launcher`, not a view `.task`: Bluetooth restoration launches have no scene. Periodic snapshots ride on HR notifications (`snapshotIfDue`), no timer.
- 2026-10-15: The live HRV skills are the vault copies (`~/Documents/Notes/.claude/skills/`), not `~/dev/skills/*` (stale Sep-12 package snapshots). StrapLog support is the `straplog` package in `tools/py` (since 2026-10-16; the old `_hrv_shared/straplog_db.py` copies are gone), declared per script via `[tool.uv.sources]` absolute path; HRV Logger parity tests stay in `_hrv_shared/tests/`. `h10` skill routes by activity. The vault is not under git: back up before editing.
- 2026-10-17: A new Watch needs registering before a sideloaded Watch app installs (Watch app's Install silently reverts otherwise): watchOS platform component in Xcode, Developer Mode on the Watch, pair in Devices and Simulators, then `xcodebuild -scheme StrapLogWatch -destination 'id=<watch udid>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`.
- 2026-10-18: Reinstalling wipes `live.sqlite`; `SnapshotImport` (run on each foreground) brings snapshots back. A file imports only the recording named by its `Snapshot.fileName`, because the legacy v2 export `261016-0805-STRENGTH_261016.sqlite` holds 9 recordings, 7 of them deleted since.
