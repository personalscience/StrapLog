# /// script
# dependencies = ["numpy", "scipy"]
# ///
"""Writes Tests/fixtures/<name>.json for RSA (heart rate following the breath, straplog-9fr.1):
the chest beats of a StrapLog export, the steps of an ArmLog Training recording made at the same
time (same phone, so both clocks are the phone's epoch ms), and reference RSA numbers per step.

Usage: gen_rsa_fixture.py --beats STRAPLOG.sqlite --pacer ARMLOG.sqlite --name NAME

The JSON holds no absolute epoch times, names or device ids (the repo is public):
- `t_end_ms` (ms from the first beat) and `rr_ms` (the key ReplayHeartSource reads);
- `steps`: label, `from_ms`/`to_ms` (marker to next marker), `pacer` (what ran, or null) and
  `breath_ref`, the pacer the reference uses: the real one, or a virtual one for steps without
  (holds and the move carry the preceding pacer on; settle gets 6/min from its marker);
- `reference` per step over [`from_ms`, `to_ms`), which starts 10 s after the pacer start (or the
  marker), by two independent methods:
  - `bandpass`: HR resampled at 4 Hz, Butterworth 0.05–0.45 Hz zero-phase, swing = 2√2·SD, and the
    Welch spectral peak (/min), as in tools/arm_breath_replay.py; `bandpass_marker` is the same over
    marker + 10 s to the next marker, the window of the calibration vault note (it reproduces that
    note's numbers; at follow_8 it reads high because its first 6 s are still 4.5/min breathing);
  - `cosinor`: least squares hr(τ) = m + c·τ + a·cos ωτ + b·sin ωτ on the cleaned instant HR
    samples (no resampling), ω from `breath_ref`, τ from the window's first inhale start. Fitted
    once over every whole breath in the window (`whole`), and over each run of 4 whole breaths
    (`windows`, stride one breath; `median_swing`). Swing = 2√(a²+b²), sync = 1 − SS_res/SS_trend,
    peak = atan2(b, a)/2π mod 1 (fraction of the breath from inhale start);
  - `breaths`: per pacer breath, max − min HR (null with < 4 samples or a hole > 3 s).
Instant HR: RRCleaner (gate 300–2000 ms, 5-beat centred median ±25%, 3 passes) over the whole
recording; each kept beat gives hr = 60000/rr at t = t_end − rr/2."""
import argparse, json, math, re, sqlite3
from pathlib import Path
import numpy as np
from scipy import signal

DROP_MS = 10_000
WINDOW_BREATHS = 4
MIN_BEATS_PER_BREATH = 4
MAX_HOLE_MS = 3_000

ap = argparse.ArgumentParser()
ap.add_argument("--beats", required=True); ap.add_argument("--pacer", required=True)
ap.add_argument("--name", required=True)
args = ap.parse_args()

# ---------------------------------------------------------------- sources
arm = sqlite3.connect(Path(args.pacer).expanduser())
chest = sqlite3.connect(Path(args.beats).expanduser())
arm_rid, arm_t0, arm_t1 = arm.execute("select id, started_at_ms, ended_at_ms from recording").fetchone()
chest_rid = chest.execute("select id from recording where started_at_ms<=? and ended_at_ms>=?",
                          (arm_t0, arm_t1)).fetchone()[0]
rows = chest.execute("select t_end_ms_est, rr_ms from beat where recording_id=? order by id",
                     (chest_rid,)).fetchall()
origin = rows[0][0]
t_end = np.array([r[0] - origin for r in rows], float)
rr = np.array([r[1] for r in rows], float)

events = arm.execute("select at_ms, kind, label, note from event where recording_id=? order by at_ms",
                     (arm_rid,)).fetchall()
markers = [(t, l) for t, k, l, _ in events if k == "marker" and l != "training"]
pacers = []   # dicts in relative ms
for i, (t, k, _, note) in enumerate(events):
    if k == "pacer_start":
        m = re.match(r"([\d.]+)/min in([\d.]+) out([\d.]+) t0=(\d+)", note)
        stop = next(a for a, kk, _, _ in events[i + 1:] if kk == "pacer_stop")
        rate, i_s, o_s = float(m[1]), float(m[2]), float(m[3])
        period = 60 / rate   # the note rounds inhale/exhale to 0.1 s; keep its ratio, exact period
        pacers.append({"start_ms": t - origin, "stop_ms": stop - origin, "breaths_per_minute": rate,
                       "inhale_s": period * i_s / (i_s + o_s), "exhale_s": period * o_s / (i_s + o_s),
                       "t0_ms": int(m[4]) - origin})

# ---------------------------------------------------------------- RRCleaner (mirrors HRVKit)
def clean(x, gate=(300, 2000), pct=0.25, iters=3):
    v = [r if gate[0] <= r <= gate[1] else None for r in x]
    for _ in range(iters):
        med = []
        for i in range(len(v)):
            p = sorted(y for y in v[max(0, i - 2):i + 3] if y is not None)
            med.append(None if len(p) < 3 else
                       (p[len(p) // 2] if len(p) % 2 else (p[len(p) // 2 - 1] + p[len(p) // 2]) / 2))
        flagged = False
        for i in range(len(v)):
            if v[i] is not None and med[i] is not None and abs(v[i] - med[i]) / med[i] > pct:
                v[i] = None; flagged = True
        if not flagged: break
    return np.array([y is not None for y in v])

kept = clean(rr)
hr_t = t_end[kept] - rr[kept] / 2          # ms
hr = 60_000 / rr[kept]

# ---------------------------------------------------------------- methods
def bandpass(a, b):
    k = (t_end >= a) & (t_end < b) & kept
    grid = np.arange(a, b, 250)
    h = np.interp(grid, t_end[k], 60_000 / rr[k])
    f, P = signal.welch(signal.detrend(h), fs=4, nperseg=min(len(h), 256))
    band = (f >= 0.05) & (f <= 0.5)
    hb = signal.sosfiltfilt(signal.butter(2, [0.05, 0.45], btype="band", fs=4, output="sos"), h)
    return {"swing_bpm": 2 * math.sqrt(2) * hb.std(), "peak_per_min": f[band][P[band].argmax()] * 60}

def cosinor(s, e, period_ms):
    k = (hr_t >= s) & (hr_t < e)
    if k.sum() < 8: return None
    tau = (hr_t[k] - s) / 1000; y = hr[k]; w = 2 * math.pi / (period_ms / 1000)
    X = np.column_stack([np.ones_like(tau), tau, np.cos(w * tau), np.sin(w * tau)])
    beta, *_ = np.linalg.lstsq(X, y, rcond=None)
    res = y - X @ beta
    trend = y - X[:, :2] @ np.linalg.lstsq(X[:, :2], y, rcond=None)[0]
    a, b = beta[2], beta[3]
    return {"from_ms": round(s), "to_ms": round(e), "n": int(k.sum()), "mean_bpm": beta[0],
            "slope_bpm_per_s": beta[1], "swing_bpm": 2 * math.hypot(a, b),
            "sync": 1 - (res @ res) / (trend @ trend), "peak_fraction": (math.atan2(b, a) / (2 * math.pi)) % 1}

def breath_swing(s, e):
    k = (hr_t >= s) & (hr_t < e)
    t = np.concatenate([[s], hr_t[k], [e]])
    ok = k.sum() >= MIN_BEATS_PER_BREATH and np.diff(t).max() <= MAX_HOLE_MS
    return {"from_ms": round(s), "to_ms": round(e), "n": int(k.sum()),
            "swing_bpm": float(hr[k].max() - hr[k].min()) if ok else None}

def rnd(x):
    if isinstance(x, float): return round(x, 4)
    if isinstance(x, dict): return {k: rnd(v) for k, v in x.items()}
    if isinstance(x, list): return [rnd(v) for v in x]
    return x

# ---------------------------------------------------------------- steps
steps, prev_ref = [], None
for i, (mt, label) in enumerate(markers[:-1]):
    a, b = mt - origin, markers[i + 1][0] - origin
    p = next((p for p in pacers if a <= p["start_ms"] < b), None)
    pacer = None if p is None else {k: p[k] for k in ("breaths_per_minute", "inhale_s", "exhale_s", "t0_ms")}
    if pacer:
        ref = dict(pacer, virtual=False)
    elif prev_ref:
        ref = dict(prev_ref, virtual=True)
    else:   # settle: free breathing against a 6/min pacer nobody followed
        ref = {"breaths_per_minute": 6.0, "inhale_s": 5.0, "exhale_s": 5.0, "t0_ms": a, "virtual": True}
    prev_ref = {k: v for k, v in ref.items() if k != "virtual"}
    w0 = (p["start_ms"] if p else a) + DROP_MS
    w1 = p["stop_ms"] if p else b
    period = 60_000 / ref["breaths_per_minute"]
    k0 = math.ceil((w0 - ref["t0_ms"]) / period); k1 = math.floor((w1 - ref["t0_ms"]) / period)
    bounds = [ref["t0_ms"] + k * period for k in range(k0, k1 + 1)]   # whole breaths in the window
    windows = [c for j in range(len(bounds) - WINDOW_BREATHS)
               if (c := cosinor(bounds[j], bounds[j + WINDOW_BREATHS], period))]
    swings = [w["swing_bpm"] for w in windows]
    steps.append({"label": label, "from_ms": a, "to_ms": b, "pacer": pacer, "breath_ref": ref,
                  "reference": {
                      "from_ms": w0, "to_ms": w1,
                      "bandpass": bandpass(w0, w1),
                      "bandpass_marker": bandpass(a + DROP_MS, b),
                      "cosinor": {"whole": cosinor(bounds[0], bounds[-1], period) if len(bounds) > 1 else None,
                                  "median_swing_bpm": float(np.median(swings)) if swings else None,
                                  "windows": windows},
                      "breaths": [breath_swing(s, e) for s, e in zip(bounds, bounds[1:])]}})

out = {"source": {"beats": "StrapLog H10 export, chest", "pacer": "ArmLog Training 'calibration v1'",
                  "generator": "tools/gen_rsa_fixture.py"},
       "constants": {"drop_ms": DROP_MS, "window_breaths": WINDOW_BREATHS,
                     "min_beats_per_breath": MIN_BEATS_PER_BREATH, "max_hole_ms": MAX_HOLE_MS,
                     "rr_gate_ms": [300, 2000], "pct_thresh": 0.25, "clean_iterations": 3},
       "t_end_ms": [int(v) for v in t_end], "rr_ms": [float(v) for v in rr],
       "removed_indices": [int(i) for i in np.flatnonzero(~kept)],
       "steps": rnd(steps)}
path = Path(__file__).resolve().parent.parent / "Tests/fixtures" / f"{args.name}.json"
path.write_text(json.dumps(out, separators=(",", ":")))

print(f"{path.name}: {len(rr)} beats, {int((~kept).sum())} removed, {len(steps)} steps")
print(f"{'step':12} {'rate':>5} {'virt':>4} {'bp marker':>9} {'bp swing':>8} {'bp peak':>7} {'cos whole':>9} {'sync':>5} "
      f"{'peak':>5} {'cos med4':>8} {'breath med':>10}")
for s in steps:
    r, c = s["reference"], s["reference"]["cosinor"]
    w = c["whole"] or {}
    bs = [b["swing_bpm"] for b in r["breaths"] if b["swing_bpm"] is not None]
    f = lambda v, fmt="{:.1f}": "—" if v is None else fmt.format(v)
    print(f"{s['label']:12} {s['breath_ref']['breaths_per_minute']:5g} {'v' if s['breath_ref']['virtual'] else '':>4} "
          f"{r['bandpass_marker']['swing_bpm']:9.1f} {r['bandpass']['swing_bpm']:8.1f} {r['bandpass']['peak_per_min']:7.1f} {f(w.get('swing_bpm')):>9} "
          f"{f(w.get('sync'), '{:.2f}'):>5} {f(w.get('peak_fraction'), '{:.2f}'):>5} "
          f"{f(c['median_swing_bpm']):>8} {f(float(np.median(bs)) if bs else None):>10}")
