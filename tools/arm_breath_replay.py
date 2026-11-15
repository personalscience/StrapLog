# /// script
# dependencies = ["numpy", "scipy", "matplotlib"]
# ///
"""Does BreathTracker follow breathing on the arm? (straplog-xz4.6)

Replays an ArmLog Training-mode recording (`calibration` script) through StrapLogCore's own
BreathTracker (tools/BreathReplay), a fresh tracker per `pacer_start` as the app does, against the
true pacer and against wrong ones (half a breath shifted; off rate). The same replay runs on the
arm's 1 Hz `motion` rows and on the chest H10's 1 Hz `motion` rows (the reference: the method the
`breathing-motion` fixture validates). RSA from the chest beats is a second reference.

Usage: arm_breath_replay.py ARM.sqlite CHEST.sqlite OUTDIR
Writes OUTDIR/results.md (tables for the vault note) and OUTDIR/*.png."""
import csv, re, sqlite3, subprocess, sys
from pathlib import Path
import numpy as np
from scipy import signal
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent
REPLAY = ROOT / "BreathReplay"
DROP_MS = 10_000          # phase truth is soft at a step's start
STEADY_MS = 60_000        # the tracker's transient after a cold start
arm_path, chest_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------- data
arm = sqlite3.connect(arm_path)
chest = sqlite3.connect(chest_path)
arm_rid, arm_t0, arm_t1 = arm.execute("select id, started_at_ms, ended_at_ms from recording").fetchone()
# The chest file may hold several recordings: take the one that covers the arm's.
chest_rid = chest.execute("select id from recording where started_at_ms<=? and ended_at_ms>=? ",
                          (arm_t0, arm_t1)).fetchone()[0]

acc = np.array(arm.execute("select at_ms, x_mg, y_mg, z_mg from acc where recording_id=? order by idx",
                           (arm_rid,)).fetchall(), float)
def motion(db, rid):
    return np.array(db.execute("select second_ms, gx_mg, gy_mg, gz_mg, n from motion where recording_id=? "
                               "order by second_ms", (rid,)).fetchall(), float)
arm_1hz, chest_1hz = motion(arm, arm_rid), motion(chest, chest_rid)
beats = np.array(chest.execute("select t_end_ms_est, rr_ms from beat where recording_id=? order by id",
                               (chest_rid,)).fetchall(), float)

events = arm.execute("select at_ms, kind, label, note from event where recording_id=? order by at_ms",
                     (arm_rid,)).fetchall()
markers = [(t, l) for t, k, l, _ in events if k == "marker"]
pacers = []   # (start_ms, stop_ms, rate, t0)
for i, (t, k, _, note) in enumerate(events):
    if k == "pacer_start":
        m = re.match(r"([\d.]+)/min .* t0=(\d+)", note)
        stop = next(a for a, kk, _, _ in events[i + 1:] if kk == "pacer_stop")
        pacers.append((t, stop, float(m[1]), int(m[2])))
step = {}     # label -> (marker_ms, next_marker_ms, pacer or None)
for i, (t, l) in enumerate(markers[:-1]):
    nxt = markers[i + 1][0]
    step[l] = (t, nxt, next((p for p in pacers if t <= p[0] < nxt), None))
PACED = [l for l, s in step.items() if s[2]]

# ---------------------------------------------------------------- replay
def write_samples(path, t, xyz):
    with open(path, "w") as f:
        f.write("at_ms,x,y,z\n")
        for ti, (x, y, z) in zip(t.astype(np.int64), xyz):
            f.write(f"{ti},{x:.0f},{y:.0f},{z:.0f}\n")

def replay(samples_csv, segments):
    """segments: [(name, from, to, rate, t0)] -> {name: dict of arrays}"""
    seg_csv = out / "segments.csv"
    with open(seg_csv, "w") as f:
        f.write("name,from_ms,to_ms,rate,t0_ms\n")
        for s in segments:
            f.write(",".join(str(int(v)) if i in (1, 2, 4) else str(v) for i, v in enumerate(s)) + "\n")
    res = subprocess.run(["swift", "run", "-c", "release", "--package-path", str(REPLAY), "BreathReplay",
                          str(samples_csv), str(seg_csv)], capture_output=True, text=True, check=True)
    by = {}
    for r in csv.DictReader(res.stdout.splitlines()):
        d = by.setdefault(r["name"], {"t": [], "vol": [], "still": [], "step": []})
        d["t"].append(int(r["at_ms"]))
        d["vol"].append(float(r["volume"]) if r["volume"] else np.nan)
        d["still"].append(r["still"] == "1")
        d["step"].append(float(r["in_step"]) if r["in_step"] else np.nan)
    return {k: {kk: np.array(v) for kk, v in d.items()} for k, d in by.items()}

write_samples(out / "arm51.csv", acc[:, 0], acc[:, 1:4])
# 1 Hz rows go in as one-sample notifications at each second's midpoint, as BreathFixture does.
write_samples(out / "arm1.csv", arm_1hz[:, 0] + 500, arm_1hz[:, 1:4])
write_samples(out / "chest1.csv", chest_1hz[:, 0] + 500, chest_1hz[:, 1:4])

def off_rate(rate):
    return 8.0 if rate < 7 else 6.0

segments = []
for l in PACED:
    a, b, rate, t0 = step[l][2]
    period = 60_000 / rate
    segments += [(f"{l}|true", a, b, rate, t0), (f"{l}|anti", a, b, rate, t0 + period / 2),
                 (f"{l}|off", a, b, off_rate(rate), t0)]
# Holds: the previous pacer runs on virtually through the hold, one tracker throughout.
for h, before, after in [("hold_1", "follow_8", "recover_1"), ("hold_2", "recover_1", "recover_2")]:
    a, _, rate, t0 = step[before][2]
    segments.append((f"{h}|virtual", a, step[after][2][0], rate, t0))
# Move: recover_2's pacer runs on through the move and up to after_move's own pacer.
a, _, rate, t0 = step["recover_2"][2]
segments.append(("move|virtual", a, step["after_move"][2][0], rate, t0))
# Settle: free breathing against a 6/min pacer nobody followed.
s0, s1, _ = step["settle"]
segments.append(("settle|virtual", s0, s1, 6.0, s0))

runs = {src: replay(out / f"{src}.csv", segments) for src in ("arm51", "arm1", "chest1")}

# ---------------------------------------------------------------- scoring
def pacer_volume(t, rate, t0):
    period = 60_000 / rate
    x = np.mod(np.maximum(0, t - t0), period) / period
    return (1 - np.cos(2 * np.pi * x)) / 2   # 1:1 cosine fill, as BreathPhase.volume

def inhale_crossings(t, v):
    out_, armed = [], False
    for ti, vi in zip(t, v):
        if np.isnan(vi):
            armed = False; continue
        if vi < 0.35: armed = True
        if armed and vi > 0.5: out_.append(ti); armed = False
    return np.array(out_)

def lag_s(t, v, ref, max_s=4.0):
    """Lag of v behind ref (s, positive = v later), by cross-correlation on a 5 Hz grid."""
    ok = ~np.isnan(v) & ~np.isnan(ref)
    if ok.sum() < 100: return np.nan
    a, b = v[ok] - v[ok].mean(), ref[ok] - ref[ok].mean()
    k = int(max_s * 5)
    cs = [np.dot(a[max(0, s):len(a) + min(0, s)], b[max(0, -s):len(b) - max(0, s)]) for s in range(-k, k + 1)]
    return (np.argmax(cs) - k) / 5

def on_grid(run, grid):
    if run is None or len(run["t"]) == 0: return np.full(len(grid), np.nan)
    v = np.interp(grid, run["t"], np.nan_to_num(run["vol"], nan=-9))
    v[v < 0] = np.nan
    return v

def score(src, l, kind):
    r = runs[src].get(f"{l}|{kind}")
    a, b, rate, t0 = step[l][2]
    rate_used = off_rate(rate) if kind == "off" else rate
    t, v, st = r["t"], r["vol"], r["step"]
    first_vol = t[~np.isnan(v)][0] if (~np.isnan(v)).any() else None
    steady = t >= a + min(STEADY_MS, (b - a) / 2)
    ins = st[steady & ~np.isnan(st)]
    cr = inhale_crossings(t[t >= a + DROP_MS], v[t >= a + DROP_MS])
    meas = (len(cr) - 1) / (cr[-1] - cr[0]) * 60_000 if len(cr) >= 3 else np.nan
    return dict(calib=(first_vol - a) / 1000 if first_vol else np.nan,
                cover=np.mean(~np.isnan(v[steady])), still=np.mean(r["still"]),
                in_step=np.median(ins) if len(ins) else np.nan, in_step_end=ins[-1] if len(ins) else np.nan,
                rate=meas, rate_used=rate_used)

def fmt(x, f="{:.2f}"):
    return "—" if x is None or (isinstance(x, float) and np.isnan(x)) else f.format(x)

lines = ["# Arm breath replay results", "",
         f"ArmLog `{arm_path.name}` vs chest `{chest_path.name}`. Readings after a fresh tracker at each "
         f"`pacer_start`; steady state = from 60 s after the pacer start (half the step for 60 s steps).", ""]

# Table 1: true pacer, all three sources.
lines += ["## True pacer", "",
          "| Step | Pacer /min | Source | Calibrated after s | Volume coverage (steady) | In-step median | In-step at end | Measured /min | Lag vs chest s | Lag vs pacer s |",
          "|---|---|---|---|---|---|---|---|---|---|"]
for l in PACED:
    a, b, rate, t0 = step[l][2]
    grid = np.arange(a + max(DROP_MS, STEADY_MS if b - a > 90_000 else 30_000), b, 200)
    chest_v = on_grid(runs["chest1"].get(f"{l}|true"), grid)
    pace_v = pacer_volume(grid, rate, t0)
    for src in ("arm51", "arm1", "chest1"):
        s = score(src, l, "true")
        v = on_grid(runs[src].get(f"{l}|true"), grid)
        lines.append(f"| {l} | {rate:g} | {src} | {fmt(s['calib'], '{:.0f}')} | {fmt(s['cover'], '{:.0%}')} | "
                     f"{fmt(s['in_step'])} | {fmt(s['in_step_end'])} | {fmt(s['rate'], '{:.1f}')} | "
                     f"{fmt(lag_s(grid, v, chest_v) if src != 'chest1' else np.nan, '{:+.1f}')} | "
                     f"{fmt(lag_s(grid, v, pace_v), '{:+.1f}')} |")

# Table 2: wrong pacers.
lines += ["", "## Wrong pacers (should read out of step)", "",
          "Anti = the true rate shifted half a breath; off = 8/min against 6 or 4.5, 6/min against 8 or 10.", "",
          "| Step | Source | True in-step | Anti in-step | Anti calibrated after s | Off rate | Off in-step |",
          "|---|---|---|---|---|---|---|"]
for l in PACED:
    for src in ("arm51", "arm1"):
        st, sa, so = (score(src, l, k) for k in ("true", "anti", "off"))
        lines.append(f"| {l} | {src} | {fmt(st['in_step'])} | {fmt(sa['in_step'])} | {fmt(sa['calib'], '{:.0f}')} | "
                     f"{so['rate_used']:g} | {fmt(so['in_step'])} |")

# Table 3: holds, settle, move.
def window(src, name, a, b):
    r = runs[src][name]
    k = (r["t"] >= a) & (r["t"] < b)
    v, st = r["vol"][k], r["step"][k]
    rng = np.nanmax(v) - np.nanmin(v) if (~np.isnan(v)).any() else np.nan
    return np.mean(~np.isnan(v)), rng, np.nanmedian(st) if (~np.isnan(st)).any() else np.nan, np.mean(r["still"][k])

def band_sd(t, xyz, a, b, fs=1.0):
    """SD (mg) of the breathing-band principal component, zero-phase: is the chest still breathing?"""
    grid = np.arange(a, b, 1000 / fs)
    X = np.column_stack([np.interp(grid, t, xyz[:, k]) for k in range(3)])
    X = signal.sosfiltfilt(signal.butter(2, [0.05, 0.45], btype="band", fs=fs, output="sos"),
                           signal.detrend(X, axis=0), axis=0)
    return np.linalg.svd(X - X.mean(0), compute_uv=False)[0] / np.sqrt(len(X))

lines += ["", "## Holds, settle, move", "",
          "| Window | Source | Volume shown | Volume range | In-step median | Still |", "|---|---|---|---|---|---|"]
for h in ("hold_1", "hold_2"):
    a, b, _ = step[h]
    # From +20 s the 20 s envelope holds nothing but the hold.
    for src in ("arm51", "arm1", "chest1"):
        cov, rng, ins, still = window(src, f"{h}|virtual", a + 20_000, b)
        lines.append(f"| {h} (last 10 s) | {src} | {cov:.0%} | {fmt(rng)} | {fmt(ins)} | {still:.0%} |")
a, b, _ = step["settle"]
for src in ("arm51", "arm1", "chest1"):
    cov, rng, ins, still = window(src, "settle|virtual", a + DROP_MS, b)
    lines.append(f"| settle vs a 6/min pacer nobody followed | {src} | {cov:.0%} | {fmt(rng)} | {fmt(ins)} | {still:.0%} |")
a, b, _ = step["move"]
for src in ("arm51", "arm1"):
    cov, rng, ins, still = window(src, "move|virtual", a, b)
    lines.append(f"| move (20 s) | {src} | {cov:.0%} | {fmt(rng)} | {fmt(ins)} | {still:.0%} |")

# Move recovery on the raw stream.
r = runs["arm51"]["move|virtual"]
a, b, _ = step["move"]
k = r["t"] >= a
not_still = r["t"][k][~r["still"][k]]
lines += ["", "### Move", ""]
if len(not_still):
    last_move = not_still[-1]
    back = r["t"][(r["t"] > last_move) & ~np.isnan(r["vol"])]
    lines.append(f"- Not still from +{(not_still[0] - a) / 1000:.1f} s to +{(last_move - a) / 1000:.1f} s after the "
                 f"`move` marker (the voice says \"Settle\" at +15 s); {len(not_still) * 0.2:.0f} s of not-still readings.")
    lines.append(f"- Volume back {(back[0] - last_move) / 1000:.0f} s after the last movement" if len(back) else
                 "- Volume never came back before `after_move`'s pacer start (a fresh tracker then).")
else:
    lines.append("- The tracker never flagged movement (still throughout).")

# Chest truth for the holds.
lines += ["", "### Chest breathing amplitude (zero-phase band, 1 Hz) — did the holds hold?", "",
          "| Window | Chest SD mg | Arm 51 Hz SD mg |", "|---|---|---|"]
for l in ("settle", "follow_8", "hold_1", "recover_1", "hold_2", "recover_2"):
    a, b, _ = step[l]
    lines.append(f"| {l} | {band_sd(chest_1hz[:, 0] + 500, chest_1hz[:, 1:4], a + 3_000, b):.1f} | "
                 f"{band_sd(acc[:, 0], acc[:, 1:4], a + 3_000, b, fs=10):.1f} |")

# RSA from the chest beats.
def rsa(a, b):
    t, rr = beats[:, 0], beats[:, 1]
    k = (t >= a) & (t < b) & (rr > 300) & (rr < 2000)
    if k.sum() < 20: return np.nan, np.nan
    grid = np.arange(a, b, 250)
    hr = np.interp(grid, t[k], 60_000 / rr[k])
    f, P = signal.welch(signal.detrend(hr), fs=4, nperseg=min(len(hr), 4 * 64))
    band = (f >= 0.05) & (f <= 0.5)
    hb = signal.sosfiltfilt(signal.butter(2, [0.05, 0.45], btype="band", fs=4, output="sos"), hr)
    return f[band][P[band].argmax()] * 60, 2 * np.sqrt(2) * hb.std()

lines += ["", "## RSA from the chest beats (second reference)", "",
          "| Step | Pacer /min | RSA peak /min | RSA amplitude bpm (2√2·SD) |", "|---|---|---|---|"]
for l, (a, b, p) in step.items():
    if b - a < 25_000: continue
    f, amp = rsa(a + DROP_MS, b)
    lines.append(f"| {l} | {p[2]:g} | {fmt(f, '{:.1f}')} | {fmt(amp, '{:.1f}')} |" if p else
                 f"| {l} | — | {fmt(f, '{:.1f}')} | {fmt(amp, '{:.1f}')} |")

# Packet loss.
n = arm_1hz[:, 4]
gaps = np.diff(acc[:, 0])
lines += ["", "## Arm stream", "",
          f"- `acc`: {len(acc)} samples over {(acc[-1, 0] - acc[0, 0]) / 1000:.0f} s = "
          f"{len(acc) / (acc[-1, 0] - acc[0, 0]) * 1000:.1f} Hz; largest gap {gaps.max():.0f} ms; "
          f"gaps > 100 ms: {(gaps > 100).sum()}.",
          f"- `motion.n` per second: min {n.min():.0f}, median {np.median(n):.0f}, max {n.max():.0f}; "
          f"seconds with n < 45: {(n < 45).sum()}."]

(out / "results.md").write_text("\n".join(lines) + "\n")
print("\n".join(lines))

# ---------------------------------------------------------------- figure
fig, axes = plt.subplots(len(PACED), 1, figsize=(13, 2.1 * len(PACED)), sharex=False)
for ax, l in zip(axes, PACED):
    a, b, rate, t0 = step[l][2]
    for src, c, lw in (("chest1", "#888", 1.2), ("arm51", "#c0392b", 1.2), ("arm1", "#2e86c1", 0.9)):
        r = runs[src][f"{l}|true"]
        ax.plot((r["t"] - a) / 1000, r["vol"], color=c, lw=lw, label=src)
    g = np.arange(a, b, 200)
    ax.plot((g - a) / 1000, pacer_volume(g, rate, t0), color="#27ae60", lw=0.8, ls="--", label="pacer")
    r = runs["arm51"][f"{l}|true"]
    ax2 = ax.twinx(); ax2.plot((r["t"] - a) / 1000, r["step"], color="k", lw=0.8, alpha=0.5)
    ax2.set_ylim(-1, 1); ax2.set_ylabel("in-step", fontsize=7)
    ax.set_ylim(-0.05, 1.05); ax.set_ylabel(f"{l}\n{rate:g}/min", fontsize=8)
axes[0].legend(loc="upper right", fontsize=7, ncol=4)
axes[-1].set_xlabel("s after pacer start")
fig.tight_layout(); fig.savefig(out / "arm_breath_replay.png", dpi=110)
