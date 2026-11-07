# Polar BLE SDK notes (8.4.0, released 2026-10-01)

Read before touching `StrapLog/Polar/`. Verified while planning on 2026-10-14.

- SPM `https://github.com/polarofficial/polar-ble-sdk.git`, up to next major from 8.4.0. Product `PolarBleSdk`; deps SwiftProtobuf, Zip. 8.x is async/await, no RxSwift (`documentation/MigrationGuide8.0.0-iOS.md`).
- `PolarBleApiDefaultImpl.polarImplementation(queue, features:, restoreIdentifier:)`: `restoreIdentifier` turns on CoreBluetooth state restoration.
- `startHrStreaming(id) -> AsyncThrowingStream<PolarHrData, Error>`. `PolarHrData` is an array of tuples `(hr, ppgQuality, correctedHr, rrsMs: [Int], rrAvailable, contactStatus, contactStatusSupported)`. About 1 Hz, **no device timestamp**, 0 to 2+ RRs per notification. The `hrValueReceived` observer exposes `rrs` in **1/1024 s**.
- `requestStreamSettings(id, feature: .acc)` then `startAccStreaming(id, settings:)`. Device timestamps are ns since 2000-01-01. 25/50/100/200 Hz, 2/4/8 G, values in mg.
- ECG/ACC streams **must** be stopped by the app with `stopStreaming(id, type:)` (KnownIssues). `automaticReconnection` defaults on.
- `PolarBleSdkFeature` is `CaseIterable`.
- v2 offline recording: `startRecording(id, exerciseId:, interval:, sampleType: .rr)`, `listExercises`, `fetchExercise`, `removeExercise`.
- Info.plist: `NSBluetoothAlwaysUsageDescription`, `UIBackgroundModes: [bluetooth-central]`.
- Call patterns reference: `examples/example-ios/polar-sensor-data-collector` in the SDK repo.
- Import as `@preconcurrency import PolarBleSdk`.
- **StrapLogCore takes RR as `rr1024` (1/1024 s), the H10's native unit.** `PolarHrData.rrsMs` is already rounded to ms; prefer the `hrValueReceived` observer's `rrs`. If only ms is available, `round(ms * 1.024)` can be off by one unit; record that choice in this file.

## Learned in P3 (2026-10-14)

- `deviceHrObserver` is marked deprecated ("use startHrStreaming"), but `PolarBleApiImpl.startHrObserver` still runs unconditionally whenever the HR service (0x180D) is discovered, and only it carries `rrs` in 1/1024 s. `PolarHeartSource` uses it and accepts the one deprecation warning. If a future SDK stops calling it, fall back to `startHrStreaming` + `round(ms * 1.024)` or the raw CoreBluetooth client.
- `PolarBleApi` is not class-bound: setting observers needs a `var` copy of the existential (the implementation is a class, so it mutates the same instance).
- Firmware is not in `deviceConnected`; it arrives later through DIS. P3 recorded `firmware = NULL`; since U1 (2026-10-15) `disInformationReceived(uuid:)` emits `.firmware` (0x2A26) and `.serialNumber` (0x2A25), and the session fills `recording.firmware` if still NULL. The SDK also calls `disInformationReceivedWithKeysAsStrings` for the same values; it is ignored.
- Device selection: the remembered id lives in `UserDefaults["polarDeviceId"]`; first run scans `searchForDevice(withNameContaining: "H10")` and takes the first hit. "Forget this strap" (DeviceSheet → `RecorderModel.forgetStrap` → `forgetDevice`) clears the key, disconnects, and searches again; it is refused while recording. A failed search retries every 5 s.
- `restoreIdentifier` is deliberately not set yet; P4 adds it with the restoration path.

## Learned in P4 (2026-10-15)

- `restoreIdentifier: "com.personalscience.straplog.central"` is passed to `polarImplementation`. The SDK's `CBDeviceListenerImpl.centralManager(_:willRestoreState:)` rebuilds a session for each restored peripheral and sets its delegate, but deliberately does not mark it connected until the central powers on; our `connectToDevice(rememberedId)` at launch then completes the reconnection.
- The SDK object must exist before `didFinishLaunching` returns, so `AppDelegate.init` builds `AppDependencies` (and so `PolarHeartSource`). See `docs/BACKGROUND.md`.

## Learned in P6 (2026-10-15)

- ACC needs `.feature_polar_online_streaming` in `features`; readiness arrives per connection through `PolarBleApiDeviceFeaturesObserver.bleSdkFeatureReady`. `PolarHeartSource` remembers the device there, clears it on disconnect, and (re)starts ACC whenever a recording wants it, so a reconnect mid-night resumes motion without the model's help. (Not dependable on its own: see straplog-4f1 below.)
- `PolarAccData` is `[(timeStamp: UInt64, x: Int32, y: Int32, z: Int32)]`, mg, ns on the strap's clock. Only within-batch deltas are used; wall time comes from phone receipt (`MotionReducer.timesMs`).
- Settings: `requestStreamSettings(id, feature: .acc)`, then 25 Hz and 8 G if offered, every other setting (resolution) at its max. Not yet confirmed on the strap: check the first device recording's `motion.n` is ≈ 25.
- Start always calls `stopStreaming(id, type: .acc)` first (errors ignored): a stream left running by a killed process would make the new start fail. Stop cancels the consuming task **and** calls `stopStreaming`, per KnownIssues. `applicationWillTerminate` turns motion off best-effort.
- ECG (1.2, display only, `PMDStream.ecg`): `requestStreamSettings(id, feature: .ecg)` then `startEcgStreaming(id, settings: maxSettings())`; the H10 offers 130 Hz, 14 bit, batches of ~73 samples (`(timeStamp ns, voltage µV)`). Streams only while the pacer screen shows it with the app in front (`RecorderModel.updateECGStreaming`); never written. ACC and ECG share one path in `PolarHeartSource`: `setStreaming` acts only on a change of wanted state, each stream's start/stop tasks are chained (`run`) so a stop can't land after the next start, and on every `bleSdkFeatureReady` unwanted streams get a `stopStreaming` in case a killed process left one running (an H10 left streaming stays on until its battery dies). Not yet confirmed on the strap: ECG and ACC running together during a recording, and the battery cost.
- The model calls `HeartSource.setMotionStreaming` (on at start/resume, off at Stop); sources without an accelerometer inherit a no-op.

## Duplicate HR notifications (straplog-a4m, 2026-10-15)

- Since P6 every HR notification reached `hrValueReceived` twice (same ms, same RR; recordings 3 and 4 of 2026-10-15 have Σrr ≈ 2× elapsed). Not a double `BleHrClient`: 8.4.0 appends it once for `feature_hr || feature_polar_online_streaming`. `setupDevice` starts `startHrObserver` for every `HR_SERVICE` its service monitor yields, and the monitor yields again when discovery reruns: `uuidNotAllowed` (H10 asks for encryption once PMD is used), `didModifyServices`, or `retryServiceDiscovery`. Two observer tasks then share one `hrStreams`. Likely trigger is the encryption path; not confirmed with device logs.
- Fix: `PolarHeartSource.emit` passes through `DuplicateHeartFilter` (StrapLogCore). The SDK calls the observer synchronously inside each observer task, so `withUnsafeCurrentTask` names the observer; a repeat is dropped only when another observer delivers an identical HR payload within 100 ms. Payload alone is not enough: recording 2 (one observer) has a real identical pair 1 ms apart after a BLE stall.
- `startHrStreaming` shares one upstream but yields only rounded `rrsMs`, so it is no substitute for the observer's 1/1024 s RR.
- `tools/check_snapshot.sh` fails a recording when over 1% of notifications are such repeats.

## Watch marker, Action button, link haptics (W2, straplog-9rp.7.2, 2026-10-17)

- Action button: Apple documents Action-button registration only for workout and dive apps (App Intents `StartWorkoutIntent` / dive). StrapLog is neither, so the route is the generic one: the Watch app ships `MarkNextIntent` as an App Shortcut (`StrapLogWatchShortcuts`), and the user sets Settings → Action Button → Shortcut → "Next Marker". Works on Ultra 2, watchOS 27 (verified 2026-10-17).
- The intent may run with no scene, so `PhoneLink` activates in `StrapLogWatchApp.init` and `send` waits for WCSession activation before `sendMessage`/`transferUserInfo`.
- `RemoteCommand.markNext` lets the phone choose the label (`LiveStatus.nextMarker`: after the last marker in bar order, the last repeats, a note starts over), so a cold intent needs no status.
- Haptics: `WKInterfaceDevice.play` works only while the Watch app is on screen. A background buzz therefore comes from the phone: `LinkAlertNotifier` posts a time-sensitive local notification, which iOS mirrors to the Watch while the iPhone is locked. Both use `LinkAlarm` (StrapLogCore): one buzz when beats stop (stale > disconnected > contact lost > beat gap), re-armed when beats return. Needs the Time Sensitive Notifications capability (`-allowProvisioningUpdates` added it to the profile).
- Beat gap: notifications still arriving but none with RR for `RecorderModel.beatGapAfterMs` (10 s). Checked as notifications arrive (no timer); a strap gone fully quiet shows as disconnected, or stale on the Watch after 60 s.

## Start/stop from the Watch (W3, straplog-9rp.7.3, 2026-10-17)

- The Watch sends `.start`/`.stop` with `sendMessage(_:replyHandler:)`; a message wakes the iOS app in the background (also when it was not running), and `WatchLink` runs it through `Launcher.run`, the same path as `StartRecordingIntent`. The phone replies with a `CommandReply` (its `LiveStatus` after the command, and a failure's words), so the Watch settles even if the application context lags or did not change (a stale display).
- Phone out of reach (or `sendMessage` errors): the command goes by `transferUserInfo`, the Watch shows "Waiting for iPhone…" (`PendingCommand.queued`) until the context shows the new state; Cancel withdraws the queued transfer.
- Live Activity: a WatchConnectivity wake is a plain background launch, not a `LiveActivityIntent`, so `Activity.request` is expected to be refused; `LiveActivityDisplay` retries on every status and the activity appears once the phone is opened. The Watch app itself shows the recording meanwhile. Confirmed on device 2026-10-17 (rec 23): no Live Activity until the phone app was opened. Starting it from the background would need push-to-start (APNs, so a server); not worth it while the Watch shows the recording.

## Motion lost after a reconnect (straplog-4f1, 2026-11-06)

- Recording 64 (relaunch 15 s in) kept 17 s of motion out of 2129 s; recording 54 lost motion at a 01:30 disconnect and never got it back across two reconnects. HR recovered both times. The only restart trigger was `bleSdkFeatureReady`, and the SDK can miss it: `makeFeaturesReadyCallbackWhenReady` polls on a `Timer.publish(on: .main)` against a 10 s deadline and, past that, only calls `bleSdkFeaturesReadiness`. A stream that threw or just finished was never retried either, and its error was logged as `<private>`.
- Fix: `StreamWatchdog` (Core) per wanted stream, ridden on HR notifications (`PolarHeartSource.heal`): a stream never attempted, ended ≥ 5 s ago, or silent ≥ 10 s is started again. Disconnect and stop reset it. `deviceConnected` now remembers the strap, so the watchdog starts streams even when feature-ready never fires; a start sent before PMD is ready throws and is retried. `bleSdkFeatureReady` still starts wanted streams at once and stops leftovers. Stream errors and restarts log with `privacy: .public` (Console, subsystem `com.personalscience.straplog`, category `polar`).
- Not yet confirmed on the strap: which trigger was actually missed (no device log from either night). If ACC still fails after a relaunch, the Console lines will say whether `requestStreamSettings` keeps throwing (PMD never set up on a restored session) or the start never delivers.
