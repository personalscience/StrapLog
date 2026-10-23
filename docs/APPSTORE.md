# App Store listing

Source of truth for what goes into App Store Connect (bead `straplog-kzk.6`). Paste fields as-is; `tools/check_listing.py` checks the length limits and the Polar-mark rule.

Rule from `straplog-kzk.3`: "Polar" and "H10" appear only in the one compatibility line of the description. Never in name, subtitle, keywords, promotional text or screenshots.

## App information

| Field              | Value                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| Seller             | Ensembio, Inc (team 4RZ2RJUXC8)                                                                              |
| Bundle ID          | com.personalscience.straplog                                                                                 |
| SKU                | ENS-STRAPLOG-001                                                                                             |
| Primary category   | Health & Fitness                                                                                             |
| Secondary category | Sports                                                                                                       |
| Price              | Paid, USD 0.99 tier                                                                                          |
| Content rights     | No third-party content                                                                                       |
| Availability       | 134 of 175: Americas, Asia-Pacific, Middle East/Africa, UK, Switzerland; not mainland China (ICP), not EU (DSA) |
| Mac / Vision Pro   | Both unchecked: untested; recording relies on iPhone background Bluetooth, Live Activity and the Watch      |
| Age rating         | 9+ (calculated; driven by Health or Wellness Topics = Yes, all else None/No; no override, not Made for Kids) |
| Export compliance  | `ITSAppUsesNonExemptEncryption = NO` in both Info.plists, so ASC does not ask                                |
| Support URL        | https://personalscience.com/docs/straplog/                                                                   |
| Privacy policy URL | https://personalscience.com/docs/straplog/privacy/                                                           |

## Version 1.0 text

<!-- listing:name -->
StrapLog HRV
<!-- /listing -->

<!-- listing:subtitle -->
Beat-by-beat chest strap data
<!-- /listing -->

<!-- listing:keywords -->
rmssd,dfa,alpha1,rr interval,heart rate variability,sleep,zones,breathing,threshold,recovery,aerobic
<!-- /listing -->

<!-- listing:promo -->
Record every heartbeat from your chest strap: live HRV and DFA alpha 1, overnight sleep recordings, markers from your Watch, and files you own.
<!-- /listing -->

<!-- listing:description -->
StrapLog records every heartbeat from a chest-strap heart-rate sensor and keeps it safe on your iPhone. It shows heart rate and heart-rate variability live, saves each recording as a file you own, and lets you mark moments as they happen.

StrapLog requires a Polar H10-compatible heart-rate sensor. Watches and wrist sensors do not connect.

BEAT BY BEAT
• Every RR interval the strap measures, stored as it arrives, so even a crash or a dead battery loses almost nothing.
• Live heart rate, RMSSD and DFA alpha 1, with artifact percentage so you know how clean the data is.
• Charts of HR, alpha 1 and RR that you can pinch from one minute to the whole session.

SLEEP AND MORNING READINGS
• Overnight recordings that stop themselves at your wake time, after a 5-minute resting reading if you are still lying down.
• The strap's motion sensor tells lying from upright, so the recording ends when you get up.

TRAINING ZONES
• DFA alpha 1 refreshed every 20 seconds and coloured by intensity band, for finding your aerobic and anaerobic thresholds on a walk, ride or treadmill.
• A breathing pacer for slow-breathing practice.

MARKERS
• Tap to stamp "lights out", "start stage 3" or "coffee" into the recording, from the app, the Lock Screen, the Dynamic Island, your Apple Watch or Siri.

APPLE WATCH
• See heart rate and alpha 1 on your wrist, add markers, and start or stop the recording on your iPhone. Complications for the watch face.

YOUR DATA, YOUR FILES
• Each recording is a single SQLite file in iCloud Drive or On My iPhone. Open it in Python, R or any SQLite tool.
• No account, no server, no analytics. Nothing leaves your devices unless you share it.

StrapLog is a personal measurement tool, not a medical device. It does not diagnose, treat or prevent any condition.
<!-- /listing -->

## What's New (1.0)

First release.

## App Privacy (nutrition label)

**Data Not Collected.** StrapLog has no server, account, analytics or third-party SDK that transmits data. Recordings stay on the device and in the user's own iCloud Drive; Apple does not count user-controlled iCloud storage as collection. The Polar BLE SDK talks only to the strap over Bluetooth.

## App Review

**Sign-in required:** No.

**Notes:**

> StrapLog records beat-to-beat (RR) intervals from a Bluetooth chest-strap heart-rate sensor (Polar H10-compatible). It cannot show live data without a strap, so a demo video of a full session is here: https://youtu.be/6EbFDyPiAMs (unlisted).
>
> Without a strap, the app opens to Home with a grey searching heart. You can still start and stop a recording, open the in-app Guide (? button), browse settings and see the strap sheet.
>
> Background mode bluetooth-central: an overnight sleep recording runs for 7–9 hours with the phone locked. The app must keep receiving the strap's heart-rate and RR notifications in the background, or the night's data is lost. It uses no location or audio background modes.
>
> Time-sensitive notifications: during a daytime recording, if the strap disconnects, loses skin contact or sends no beats for 10 seconds, one link alert tells the user to check the strap. Sleep recordings never send these alerts.
>
> The app is not a medical device and makes no diagnostic claims. All data stays on the device or in the user's iCloud Drive; there is no server or account.

**Demo video:** screen recording on a real device with the strap on: connect, start an Other recording, markers, Live Activity on the Lock Screen, Watch app, stop, summary, Files → iCloud Drive → StrapLog. Uploaded 2026-10-18 as an unlisted YouTube Short (screen recording plus a camera clip of the Watch).

## Support and privacy pages

Sources: `site/src/` (docs and privacy pages, shared GA4 tag; `tools/build_site.py` renders them, with the in-app Guide.md, into `site/straplog/`); `tools/publish_site.sh` builds and syncs them to the `personalscience-docs` bucket behind personalscience.com. Contact: support@personalscience.com.
