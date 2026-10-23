# CLAUDE.md — StrapLog

Personal iOS app (sideloaded, team `4RZ2RJUXC8`) that logs per-beat RR intervals from a Polar H10 to crash-safe SQLite, replacing Marco Altini's HRV Logger for Rik's HRV skills (the `straplog-skills` plugin, `~/dev/skills/straplog-skills`). Built in phases tracked as beads; the plan is `~/.claude/plans/i-d-like-to-make-velvety-wreath.md` (read only the current phase's section).

## Commands

```
xcodegen generate                                   # after any project.yml or file-tree change
(cd Packages/HRVKit && swift test)                  # pure algorithms, macOS, seconds
(cd Packages/StrapLogCore && swift test)            # model, schema, session, macOS
(cd tools/py && uv run pytest)                      # straplog Python package + CLI
xcodebuild test -scheme StrapLog -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/dd
xcodebuild -scheme StrapLog -destination 'generic/platform=iOS' -derivedDataPath build/dd build
tools/release.sh [--upload]                         # App Store archive + export (clean tree; build = commit count)
tools/screenshots.sh                                # 6.9" App Store PNGs → build/screenshots/ (~4 min real-time replay)
tools/guide_images.py                               # Guide illustrations from build/screenshots → app assets + site/straplog/img/guide
tools/check_listing.py                              # docs/APPSTORE.md lengths + no-Polar-marks rule
tools/publish_site.sh                               # build docs page (Guide.md → site/straplog/) + deploy
```

## Map

| Area | Path | Read first |
|---|---|---|
| Algorithms (RR cleaning, RMSSD, DFA α1) | `Packages/HRVKit` | constants mirror `~/dev/skills/straplog-skills/skills/h10-session/scripts/analyze_h10.py` |
| Domain, GRDB schema, `RecordingSession` | `Packages/StrapLogCore` | `docs/SCHEMA.md` before touching migrations |
| App: Polar adapter, SwiftUI, AppDelegate | `StrapLog/` | `docs/SDK-NOTES.md` before touching `StrapLog/Polar/` |
| Watch app (remote display/controller over WatchConnectivity) | `StrapLogWatch/`, `StrapLog/Watch/` | wire format is `WatchPayload` in Core; the phone stays the only recorder |
| Python reader + `straplog` CLI | `tools/py` | the HRV skills depend on it; keep `straplog.db`'s API stable |
| Tests and fixtures | `*Tests/`, `Tests/fixtures/` | `docs/TESTING.md` |
| Xcode project | `project.yml` | never hand-edit `StrapLog.xcodeproj` |
| App Store Watch screenshots (as uploaded) | `design/screenshots/watch/` | captured on a real Watch, not reproducible; iPhone ones regenerate via `tools/screenshots.sh` |

## Rules that the tree does not tell you

- Only `StrapLog/Polar/` may `import PolarBleSdk`; everything else talks to `HeartSource`. Keeps the SDK swappable for a raw CoreBluetooth client.
- Packages stay macOS-buildable (no UIKit, no SDK) so all logic is testable with `swift test` and no Bluetooth.
- Packages are Swift 6 language mode; the app target is Swift 5 mode with complete strict-concurrency checking, because the SDK's tuple typealiases are not `Sendable`.
- Times in the DB are Unix epoch ms UTC plus `tz_offset_s`. HRV Logger stored local time as UTC; never repeat that.
- Never ship a `-wal`/`-shm` off device: exports are `VACUUM INTO` single-file snapshots.
- No logic in views; one type per file.
- Phase protocol: `bd update <id> --status in_progress` → build with tests → `bd note` + `bd close` → update the plan's Status line → `git add -A` → wait for "commit".

## Vault

- Hub note: `~/Documents/Notes/Projects/Personal Science/StrapLog/StrapLog.md`
- Background (why StrapLog exists) and feature ideas: hub section *Why StrapLog exists*; `StrapLog Planning.md` beside the hub

## Learned

- 2026-10-14: `bd init` also writes AGENTS.md plus `.codex/`, `.cursor/`, `.agents/` scaffolding; removed as unused in this solo repo.
- 2026-10-14: In `async` test functions GRDB's `read`/`write` resolve to the async overloads and need `await`; keep `TestRig` helpers synchronous so tests stay terse.
- 2026-10-14: The injectable clock is `WallClock` (the stdlib owns `Clock`). Feed sessions with `HeartSource.pump(into:)`.
- 2026-10-14: The view model (`RecorderModel`) lives in StrapLogCore, not the app, so its tests run on macOS. Simulator/UI runs use `-replay resting -speed 20 -freshDatabase`. Check device exports with `tools/check_snapshot.sh`.
- 2026-10-14: `git rm` of a directory's last file deletes the directory; XcodeGen then fails on the missing source path.
- 2026-10-15: Recording work starts in `AppDelegate.didFinishLaunching` via `Launcher`, not a view `.task`: Bluetooth restoration launches have no scene. Periodic snapshots ride on HR notifications (`snapshotIfDue`), no timer.
- 2026-10-15 (revised 2026-10-23): The live HRV skills are the `straplog-skills` plugin, source `~/dev/skills/straplog-skills` (remote `personalscience/straplog-skills`); the vault copies in `~/Documents/Notes/.claude/skills/` are gone (only `polar-strength` remains there). Scripts pull the `straplog` package from PyPI (`straplog>=0.2`, source `tools/py`), so a reader API change needs a PyPI release. `_hrv_shared` (and its HRV Logger parity tests) no longer exists. `h10` routes by activity.
- 2026-10-17: A new Watch needs registering before a sideloaded Watch app installs (Watch app's Install silently reverts otherwise): watchOS platform component in Xcode, Developer Mode on the Watch, pair in Devices and Simulators, then `xcodebuild -scheme StrapLogWatch -destination 'id=<watch udid>' -allowProvisioningUpdates -allowProvisioningDeviceRegistration build`.
- 2026-10-18: Reinstalling wipes `live.sqlite`; `SnapshotImport` (run on each foreground) brings snapshots back. A file imports only the recording named by its `Snapshot.fileName`, because the legacy v2 export `261016-0805-STRENGTH_261016.sqlite` holds 9 recordings, 7 of them deleted since.
- 2026-10-18: App Store signing uses Ensembio's cloud-managed "Distribution Managed" cert (no private key in the keychain); `-allowProvisioningUpdates` makes the App Store profiles. `-exportArchive` needs the system PATH: Homebrew rsync 3.x rejects the `-E` Xcode's openrsync passes ("Copy failed").
- 2026-10-18: A `devicectl device install` that hangs with the phone wired and unlocked is a wedged Mac-side service: `killall CoreDeviceService`, then retry with `--timeout 120`.
