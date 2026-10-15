# Background operation and its limits

How StrapLog keeps recording with the screen locked, what iOS can still take away, and how the
data shows it. Read before touching `AppDelegate`, `Launcher` or `PolarHeartSource`.

## What keeps the app alive

- `UIBackgroundModes: bluetooth-central` (in `project.yml`). While the H10 is connected and
  notifying (~1 Hz), iOS wakes the app for every notification, so the process keeps running
  locked and in the background. No timer or `BackgroundTasks` job is needed: everything
  periodic is driven by the notifications themselves.
- Periodic export: after each HR notification `RecordingSession.snapshotIfDue` writes a
  `VACUUM INTO` snapshot if 30 min (`RecorderModel.defaultSnapshotEveryMs`) have passed since the
  recording's last one (or its start). A move to the background also snapshots. After a
  relaunch the cadence continues from the last `snapshot` event.
- The live database is WAL with one transaction per notification, so a kill loses at most the
  notification being written.

## When iOS kills the app

- **Memory pressure or a crash while connected.** CoreBluetooth state restoration
  (`restoreIdentifier` in `PolarHeartSource`) makes iOS relaunch the app in the background on
  the next event from the strap. The launch runs `AppDelegate.init` (builds the Polar central
  with the same restore id) and `didFinishLaunching` → `Launcher.start()` →
  `RecorderModel.launch()` → `RecordingSession.resumeIfOpen()` → `relaunch` event, then
  `consume` reconnects and data continues in the same recording. No SwiftUI scene exists in
  such a launch, which is why the work is not started from a view `.task`.
- **Force-quit from the app switcher.** iOS does *not* restore an app the user swiped away.
  Recording stops until StrapLog is opened again; that launch resumes the open recording
  (`relaunch`, then `connect`). The gap is bracketed by `relaunch`/`connect` in `coverage`.
- **Reboot.** Restoration does not survive a reboot either. Opening the app after the reboot
  resumes the recording if it went silent less than 6 h ago (`defaultStaleAfterMs`); otherwise it
  is closed at its last activity with a `stop` noted `stale`.
- **Bluetooth turned off.** Logged as `ble_off` (and usually `disconnect`); turning it on logs
  `ble_on`, and the SDK's automatic reconnection logs `connect`.
- **Out of range.** `disconnect` with the SDK's reason; `connect` when the strap returns. The
  SDK reconnects automatically (`automaticReconnection` defaults on).

## Things that degrade recording

- **Low Power Mode**: not yet measured on device. Bluetooth background execution is not
  documented as suspended by it; record the first overnight under Low Power Mode here.
- **Strap battery.** A strap reading ≤ 10 % logs one `low_battery` event per recording.
- **Phone battery dies.** Everything up to the last committed notification is in the live
  database; exports are as fresh as the last snapshot (≤ 30 min old).

## Measuring it: `Coverage`

`Coverage.of(recording:db:)` (StrapLogCore) takes the span from first to last notification and
lists every silence longer than 3 s as a `CoverageGap`, with the events logged inside it. A gap
is *bracketed* when a down event (`disconnect`, `ble_off`, `relaunch`) is followed by an up event
(`connect`, `ble_on`) inside it. `tools/check_snapshot.sh` prints the same numbers from a device
export with plain `sqlite3`.

P4 acceptance: one overnight ≥ 7.5 h locked with coverage ≥ 0.98, or every gap bracketed.

## Device fault-injection protocol

Start a recording, lock the phone, then for each fault check the export with
`tools/check_snapshot.sh` and look for the expected events:

| Fault | Expected events in the gap | Same recording? |
|---|---|---|
| Walk out of range ~1 min | `disconnect … connect` | yes |
| Bluetooth off/on in **Settings** | `ble_off disconnect … ble_on connect` | yes |
| Bluetooth toggle in Control Centre (disconnects accessories without powering the radio off) | likely `disconnect … connect` only; record what is seen | yes |
| Force-quit, wait 1 min, reopen | `relaunch connect` (plus `foreground`) | yes |
| Reboot, unlock, reopen | `relaunch connect` | yes (if < 6 h) |
