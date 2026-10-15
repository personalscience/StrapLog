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
