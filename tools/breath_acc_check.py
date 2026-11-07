# /// script
# dependencies = ["numpy", "scipy", "matplotlib"]
# ///
"""Feasibility: does the H10's per-second gravity vector (motion.gx/gy/gz_mg) carry breathing?

Usage: breath_acc.py FILE.sqlite OUT.png [--pacer]  (uses the recording's longest pacer session,
or, without --pacer, a 15-min window from the middle of the recording)."""
import re, sqlite3, sys
import numpy as np
from scipy import signal
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

path, out = sys.argv[1], sys.argv[2]
use_pacer = "--pacer" in sys.argv
db = sqlite3.connect(path)
rid = db.execute("select id from recording").fetchone()[0]
m = np.array(db.execute("select second_ms,gx_mg,gy_mg,gz_mg,rms_mg from motion where recording_id=? order by second_ms", (rid,)).fetchall(), float)

if use_pacer:
    ev = db.execute("select at_ms, note from event where recording_id=? and kind in ('pacer_start','pacer_stop') order by at_ms", (rid,)).fetchall()
    best = None
    for i, (at, note) in enumerate(ev):
        if note and note.startswith(tuple("0123456789")):
            stop = next((a for a, n in ev[i + 1:]), m[-1, 0])
            mm = re.match(r"([\d.]+)/min in([\d.]+) out([\d.]+)(?: t0=(\d+))?", note)
            rate, tin, tout = float(mm[1]), float(mm[2]), float(mm[3])
            t0 = float(mm[4]) if mm[4] else at
            if best is None or stop - at > best[1] - best[0]:
                best = (at, stop, rate, tin, tout, t0)
    a, b, rate, tin, tout, t0 = best
    a += 60_000  # skip the first minute (settling)
else:
    mid = (m[0, 0] + m[-1, 0]) / 2
    a, b = mid - 450_000, mid + 450_000
    rate = None

sel = (m[:, 0] >= a) & (m[:, 0] < b)
t = m[sel, 0]; g = m[sel, 1:4]; rms = m[sel, 4]
# resample onto a strict 1 Hz grid (fills the odd missing second)
grid = np.arange(t[0], t[-1] + 1, 1000.0)
g = np.column_stack([np.interp(grid, t, g[:, k]) for k in range(3)])
gaps = len(grid) - sel.sum()
fs = 1.0
# breathing band 3–30/min
sos = signal.butter(2, [0.05, 0.45], btype="band", fs=fs, output="sos")
gf = signal.sosfiltfilt(sos, signal.detrend(g, axis=0), axis=0)
# first principal component = the breathing axis
u, s, vt = np.linalg.svd(gf - gf.mean(0), full_matrices=False)
pc = gf @ vt[0]
pc_share = s[0] ** 2 / (s ** 2).sum()

f, p = signal.welch(pc, fs=fs, nperseg=256)
peak = f[np.argmax(p)]
band = (f > 0.05) & (f < 0.45)
peak_win = band & (np.abs(f - peak) <= 0.015)
peak_share = p[peak_win].sum() / p[band].sum()

lines = [f"{path.split('/')[-1]}  window {(grid[-1]-grid[0])/60000:.1f} min, gaps {gaps}s",
         f"axis weights (x,y,z) {np.round(vt[0], 2)}  PC1 share {pc_share:.0%}",
         f"breath amplitude (PC1 peak-to-peak, median per 60 s) {np.median([np.ptp(pc[i:i+60]) for i in range(0, len(pc)-60, 60)]):.1f} mg",
         f"rms_mg (movement) median {np.median(rms):.1f} mg",
         f"spectral peak {peak*60:.2f}/min, {peak_share:.0%} of 3–30/min power within ±0.9/min"]

if rate:
    # Reference pacer: lung volume ramps up over `in`, down over `out` (cosine halves).
    period = 60.0 / rate
    ph = ((grid - t0) / 1000.0) % period
    ref = np.where(ph < tin, -np.cos(np.pi * ph / tin), np.cos(np.pi * (ph - tin) / tout))
    ref = signal.sosfiltfilt(sos, ref)
    # sign: choose so that pc tracks inhale positive
    sign = np.sign(np.corrcoef(pc, ref)[0, 1]); pc *= sign
    lags = np.arange(-5, 6)
    xc = [np.corrcoef(pc[5:-5], np.roll(ref, L)[5:-5])[0, 1] for L in lags]
    best_lag = lags[int(np.argmax(xc))]
    win = [np.corrcoef(pc[i:i+60], np.roll(ref, best_lag)[i:i+60])[0, 1] for i in range(0, len(pc) - 60, 30)]
    lines += [f"pacer {rate}/min in{tin} out{tout}: r={max(xc):.2f} at lag {best_lag:+d}s (breath lags pacer if +)",
              f"60-s windows: median r {np.median(win):.2f}, ≥0.7 in {np.mean(np.array(win) >= 0.7):.0%}, min {min(win):.2f}"]
print("\n".join(lines))

fig, ax = plt.subplots(3, 1, figsize=(11, 8.5))
mins = (grid - grid[0]) / 60000
k = slice(0, min(180, len(pc)))
ax[0].plot(mins[k] * 60, pc[k], label="ACC breathing component (mg)")
if rate:
    ax[0].plot(mins[k] * 60, ref[k] * np.std(pc) / np.std(ref), alpha=.6, label="pacer (scaled)")
ax[0].set_xlabel("s"); ax[0].legend(loc="upper right"); ax[0].set_title("first 3 minutes of window")
ax[1].plot(mins, pc, lw=.6); ax[1].set_xlabel("min"); ax[1].set_title("whole window")
ax[2].semilogy(f * 60, p); ax[2].set_xlim(0, 30); ax[2].set_xlabel("breaths/min"); ax[2].set_title("spectrum")
fig.suptitle("\n".join(lines[:1] + lines[-2:]), fontsize=8)
fig.tight_layout(); fig.savefig(out, dpi=110)

# --- Independent check: ACC breathing vs RSA (heart rate) and vs pacer, by phase locking ---
b = np.array(db.execute("select t_end_ms_est, rr_ms from beat where recording_id=? order by t_end_ms_est", (rid,)).fetchall(), float)
ok = (b[:, 1] > 300) & (b[:, 1] < 2000)
hr = np.interp(grid, b[ok, 0], 60000 / b[ok, 1])
hrf = signal.sosfiltfilt(sos, signal.detrend(hr))
narrow = signal.butter(2, [max(peak - 0.03, 0.03), peak + 0.03], btype="band", fs=fs, output="sos")
phase = lambda x: np.angle(signal.hilbert(signal.sosfiltfilt(narrow, x)))
pa, ph_hr = phase(pc), phase(hrf)
def plv(d):  # 1 = constant phase relation, 0 = none
    return np.abs(np.mean(np.exp(1j * d)))
def report(name, other):
    d = pa - other
    w = [plv(d[i:i+60]) for i in range(0, len(d) - 60, 30)]
    lag_s = np.angle(np.mean(np.exp(1j * d))) / (2 * np.pi * peak)
    print(f"ACC vs {name}: PLV whole {plv(d):.2f}, 60-s windows median {np.median(w):.2f} (min {min(w):.2f}), mean offset {lag_s:+.1f}s")
report("HR (RSA)", ph_hr)
if rate:
    report("pacer", phase(ref))
    print(f"HR  vs pacer: PLV whole {plv(ph_hr - phase(ref)):.2f}")
if rate:
    slip = np.unwrap(pa - phase(ref)) / (2 * np.pi)  # cycles ahead of the pacer
    print("slip vs pacer, cycles, per minute:", np.round(slip[::60] - slip[0], 2))
    print("slip HR vs pacer:                 ", np.round((np.unwrap(ph_hr - phase(ref)) / (2*np.pi))[::60] - np.unwrap(ph_hr - phase(ref))[0]/(2*np.pi), 2))
