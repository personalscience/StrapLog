# Understanding Your Numbers

StrapLog records every heartbeat your Polar H10 detects and turns them into a few heart-rate-variability (HRV) measures. This guide explains each one, what a "good" reading looks like, and when to distrust a number.

StrapLog is a personal measurement tool, not a medical device. Use it to compare yourself against yourself.

---

## The recording screen

**The heart (top left)** shows the strap's link: red and glowing when connected, grey and pulsing while searching, orange and broken when disconnected or Bluetooth is off. Tap it for the **device sheet** (see below). The title shows elapsed time and the recording's name; **?** opens this guide.

**Heart rate (bpm), left tile.** The strap's own beats-per-minute reading, sent about once a second. It is smoothed by the strap, so it lags sudden changes by a few seconds. A warning appears under it when the strap loses skin contact.

**DFA α1, right tile.** The latest α1, refreshed every **20 seconds**. The whole tile takes the colour of its intensity band (see *DFA α1* below), so a glance tells you whether you are under or over the 0.75 line.

**The line beneath** shows the latest window's RMSSD, its artifact %, and how long ago α1 was computed. If that age keeps growing, too few clean beats are arriving for a window.

**The chart.** Pick **HR**, **α1** or **RR** (the tachogram). The chart always ends at now. **Pinch** to zoom out (1, 2, 5, 15, 30, 60 min, whole recording) or in; **double-tap** to return to 5 minutes; or tap the span chip to pick one. The α1 view shades the bands and draws the 0.75 and 0.50 lines. Markers appear as labelled dashed lines on every view. The app remembers your last view and span.

**Stop…** asks before it stops the recording and writes the export. **Pacer** opens the breathing pacer for activities that use it.

In landscape, the numbers sit on the left and the chart fills the right.

## The device sheet

**Device ID, firmware, serial, battery.** The H10's printed ID and what it reports about itself. Replace the CR2025 battery when it reads below about 20 %. A weak battery is the most common cause of dropouts.

**Link.** "Searching," "H10 *id*," "Disconnected — reconnecting," or "Bluetooth is off." StrapLog keeps the recording open through disconnects and picks up again when the strap comes back.

**Skin contact.** The H10 reports whether its electrodes touch skin. Poor contact produces noisy or missing beats. Wet the electrodes and tighten the strap.

**Beats.** How many individual heartbeats (RR intervals) have been saved. At rest this grows by roughly your heart rate each minute. If it stalls while the heart-rate number keeps updating, the strap is not sending beat data; check its contact.

**Since last notification.** Seconds since the strap last reported in. It normally stays under 1.5 s. A climbing number means the Bluetooth link has dropped.

**Longest gap.** The longest silence in this recording. Beats that happen during a gap are lost: the strap does not store them. A few gaps of 2–3 s in an overnight recording are normal. Gaps of 30 s or more mean a stretch of missing data, so check the analysis for windows that were skipped.

**Last export.** Where the most recent export file was written.

## Markers

Tap **a**, **b**, **c** or **end**, or tap **+** to type a note, to stamp the current moment, for example "lying down," "start stage 3," or "coffee." Notes you have used before are offered again for one-tap reuse. Markers are saved with the recording, so analysis can split a session into parts (rest vs. exercise, before vs. after). They do not change any measurement.

**Long-press the marker row** to edit its buttons: add, rename, delete or reorder them. Each activity keeps its own set (Sleep's *lights out / awake / up* are separate from Other's), the change applies at once, even mid-recording, and **Restore defaults** brings back the original set.

## The recordings list

Each row shows the name, local start time, duration and beat count. **open** means the recording was never stopped. If the app was killed mid-recording, it reattaches to that recording on the next launch rather than starting a new one.

After **Stop**, a **Last recording** card on Home sums up the session:

- **Duration**, **Mean HR** and **RMSSD** over the whole recording, after artifact removal.
- **Lowest HR**: the lowest 2-minute average. For a night, this is your sleeping low. It uses a 2-minute average so that one missed beat cannot fake a low.
- **Artifacts**: the share of beats removed as artifacts.
- **Coverage**: the share of the recording that had heart data.
- **Minutes per α1 band**: one minute for each 2-minute window, counted in the band of its α1.

Tap the card or any row to open the recording. There you can see the summary, the chart of the whole session (pinch to zoom) and the markers with their clock times. You can also change the name, activity and notes. Saving renames the export file to match and writes it again. **Share export** sends the file; **Export again** writes it back if it was removed from iCloud Drive. Swipe a row left to delete it.

---

## Shortcuts, Siri and the Action button

StrapLog offers **Start Recording** (pick an activity), **Stop Recording** and **Add Marker** to Shortcuts, Siri ("Start Sleep recording in StrapLog") and the Action button. They work without opening the app. Starting while a recording is open leaves it running. A Sleep start uses the wake time set on the Start screen.

To start a sleep recording automatically at bedtime:

1. Open Shortcuts → Automation → New Automation → Sleep (or Focus → Sleep).
2. Choose **When Turning On**, then **Run Immediately**.
3. Add the action **Start Recording** from StrapLog and set Activity to **Sleep**.

Put the strap on before Sleep Focus turns on, so the night's first beats are caught.

## The measurements

### RR interval (ms)

The time from one heartbeat to the next, in milliseconds, measured from the R-peak of your ECG. This is the raw material for everything else. 1000 ms between beats equals 60 bpm; 500 ms equals 120 bpm (bpm = 60 000 ÷ RR).

The **tachogram** plots RR over time. Up means slower beats, down means faster. At rest it should rise and fall with your breathing: beats speed up on the in-breath and slow down on the out-breath (respiratory sinus arrhythmia). Big, smooth waves are a sign of a relaxed, vagally dominated state. A flat line means low variability, which is normal during hard exercise and a warning sign at rest.

The H10 measures RR from a true ECG signal, accurate to about 1 ms. Wrist optical sensors can't match that, which is why StrapLog uses a chest strap.

### Artifacts and artifact %

Not every reported beat is real. A missed beat shows up as one interval twice as long as usual. An extra or premature beat (ectopic beat) shows up as a short one followed by a long one. Movement and poor contact add more. StrapLog removes suspect beats before computing anything:

1. It discards any interval shorter than 300 ms (above 200 bpm) or longer than 2000 ms (below 30 bpm).
2. It compares each beat to the median of its five-beat neighbourhood and drops any beat more than 25 % away from it. This is repeated up to three times.

**Artifact %** is the share of beats removed in the current window.

| Artifact % | Meaning |
|---|---|
| under 2 % | Clean. Trust every metric. |
| 2–5 % | Usable for RMSSD and heart rate. Treat DFA α1 with care. |
| over 5 % | Fix the strap before reading anything into DFA α1. RMSSD may be inflated. |

Occasional ectopic beats are common and usually harmless, but they inflate HRV. That is why cleaning matters.

### Analysis windows

The HRV measures are computed over a **2-minute window** that moves forward every **60 seconds** in the analysis (the on-screen α1 tile steps every **20 seconds** over the same 2-minute window, so it reacts sooner but still describes the last 2 minutes). Each window is cleaned on its own. A window needs at least **60 beats**, both before and after cleaning, or it is skipped (shown as "--"). So:

- The first value appears about 2 minutes after you start.
- Every value describes the *previous* 2 minutes, not this instant. After a change in effort or posture, wait 2–3 minutes before reading the new level.

### Window heart rate (bpm)

The average heart rate over the window, computed from the cleaned RR intervals (60 000 ÷ mean RR). It is steadier than the live strap number and is the value to quote for a window.

### RMSSD (ms)

**Root mean square of successive differences:** how much each beat's interval differs from the one before, averaged over the window. It captures fast, beat-to-beat changes, which are driven mainly by the vagus nerve (the parasympathetic "rest and digest" system).

- **Higher means more vagal activity.** That usually means better recovery, lower stress and readiness for training.
- **Lower** than your normal suggests strain: hard training, poor sleep, alcohol, illness coming on, travel or psychological stress.
- Typical resting values in healthy adults range from about 20 to 100 ms. They fall with age and vary widely between people, so **another person's number tells you nothing about yours.** Compare against your own baseline.
- Measure under the same conditions each time (for example, on waking, lying still, after 1–2 minutes of settling). Posture, breathing, talking and caffeine all move it.
- During exercise RMSSD collapses toward a few ms. That is expected and carries little information. Use DFA α1 instead.

### LnRMSSD

The natural logarithm of RMSSD. RMSSD is skewed: a jump from 80 to 100 ms means less than a jump from 20 to 40. Taking the log evens this out, so averages and day-to-day comparisons behave better. Most HRV research and apps track this form. (HRV4Training and Elite HRV show ln RMSSD × 20 on a 0–100-ish scale.)

| RMSSD | LnRMSSD |
|---|---|
| 20 ms | 3.0 |
| 33 ms | 3.5 |
| 55 ms | 4.0 |
| 90 ms | 4.5 |

**How to use it:** keep a rolling 7-day average of your morning value. A single low day means little. Several days running below your normal range (roughly half a standard deviation under your baseline) is the signal worth acting on.

### SDNN (ms)

**Standard deviation of all RR intervals** in the window: total variability from every source, both fast (breathing) and slow (blood-pressure and temperature rhythms, posture shifts).

- It depends heavily on recording length. A 2-minute SDNN is not comparable to the 24-hour SDNN used in cardiology studies, or to the overnight SDNN Apple Health shows. Compare only like with like.
- Slow, deep breathing raises SDNN sharply, because each breath produces a large swing in heart rate. That makes it a good gauge during paced breathing.
- At rest, SDNN and RMSSD usually move together. When SDNN is high but RMSSD is not, slow rhythms are dominating, for example after standing up.

### DFA α1 (alpha-1)

**Detrended fluctuation analysis, short-term exponent.** Instead of measuring *how much* your heartbeat varies, α1 measures the *pattern* of variation: whether one interval tends to predict the next few. It is calculated over scales of 4 to 16 beats.

- **About 1.0:** correlated, "healthy complexity." Typical at rest and during easy exercise.
- **About 0.5:** random. Each beat is unrelated to the last.
- **Below 0.5:** anti-correlated. Long beats tend to follow short ones, which happens at high intensity.

As exercise intensity rises, α1 falls in a consistent way, which makes it a strap-only way to estimate training zones without a lab test:

| α1 | Colour band | Rough intensity |
|---|---|---|
| above 1.0 | rest / very easy | Recovery effort |
| 0.75–1.0 | easy | Zone 1–2, below the aerobic threshold |
| **0.75** | **aerobic threshold (VT1)** | Top of truly easy training |
| 0.50–0.75 | moderate | Between thresholds ("tempo") |
| **0.50** | **near anaerobic threshold (VT2)** | Hard, sustainable for tens of minutes at most |
| below 0.50 | very hard | Above threshold |

**To find your thresholds,** do a gradual ramp (walking, cycling or rowing, increasing effort every 2–3 minutes). Note your heart rate or power when α1 crosses 0.75 and again at 0.5. Repeat every few months; the crossing points shift with fitness.

**Caveats:**

- α1 is very sensitive to artifacts. A few percent of bad beats push it toward 0.5 or below and make easy work look hard. Always check artifact % first.
- At rest, especially with slow breathing, α1 can run well above 1.0 (1.2–1.5). That is not a problem; resting α1 is not a recovery score.
- Because of the 2-minute window, α1 lags. Hold each effort level long enough for the window to fill with it.
- The 0.75/0.50 thresholds are averages from research groups. Your own crossing points may differ by 5–10 bpm from a lab test.

### Paced breathing

The pacer guides you to breathe at a set rate, by default **6 breaths per minute** (5 s in, 5 s out), adjustable from 4.5 to 7. At around 6 per minute, breathing, heart rate and blood pressure fall into step (resonance). The tachogram turns into large, smooth waves, and SDNN rises well above its normal resting value.

Most people have a personal **resonance rate** between 4.5 and 7 breaths per minute. To find yours, try a few rates for 2–3 minutes each on different occasions. The rate that produces the biggest, smoothest RR waves (highest SDNN) is yours. Pacer start and stop are saved as events in the recording.

Do not compare RMSSD from paced-breathing sessions against your normal resting baseline. Slow breathing inflates it.

### Motion

The H10's accelerometer is summarised once per second:

- **Motion intensity (mg, thousandths of g):** how much the chest moved during that second, with gravity removed. Near 0 means lying still. 10–50 mg means fidgeting or shallow breathing movement. Hundreds means walking or more.
- **Gravity direction:** which way the strap is facing. Changes reveal posture: lying on your back vs. side, sitting up, standing.

Overnight, motion shows when you were still (likely asleep) and when you turned over, so HRV can be compared between still periods only. During exercise it helps explain artifact spikes.

---

## Getting good data

- **Wet the electrodes** before putting the strap on, and wear it snug, just below the chest muscles, with the logo upright.
- **Settle before you read.** Give resting measurements 1–2 minutes of stillness before the first window counts.
- **Keep conditions the same** when tracking trends: same time, posture and breathing.
- **Keep the phone within a few metres**, especially overnight. Distance and walls cause gaps.
- **Replace the battery** at the first sign of dropouts.
- **Rinse the strap** after sweaty sessions; dried salt degrades contact.

## What's in an export

Tapping **Stop and export** writes a single SQLite file to *Files → iCloud Drive → StrapLog* (or *On My iPhone → StrapLog* if iCloud Drive is off), named `YYMMDD-HHMM-name.sqlite`. It contains that one recording. Each beat is stored as the strap sent it (in 1/1024 s) and in milliseconds, with an estimated timestamp. The timestamp is an estimate because the H10 doesn't stamp beats; StrapLog infers each beat's time from when the phone received it. Markers, connection events and motion are stored alongside. All times are UTC, with your time-zone offset saved per recording. If you delete and reinstall StrapLog, it reads these files back when it opens, so your recordings reappear on Home. Files iCloud has moved off the phone show up a little later, once they have downloaded.
