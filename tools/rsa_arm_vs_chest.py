# /// script
# dependencies = ["numpy", "scipy"]
# ///
"""Usage: uv run tools/rsa_arm_vs_chest.py H10.sqlite ARMBAND.sqlite (straplog-9fr.8).
H10 vs armband during StrapLog's pacer runs: RSA per 4-breath window, and the arm's
per-second gravity vector as a breath signal against the pacer."""
import math, re, sqlite3, sys
import numpy as np
from scipy import signal
chest, arm = sqlite3.connect(sys.argv[1]), sqlite3.connect(sys.argv[2])

def clean(x, gate=(300, 2000), pct=0.25, iters=3):
    v = [r if gate[0] <= r <= gate[1] else None for r in x]
    for _ in range(iters):
        med = []
        for i in range(len(v)):
            p = sorted(y for y in v[max(0, i-2):i+3] if y is not None)
            med.append(None if len(p) < 3 else (p[len(p)//2] if len(p) % 2 else (p[len(p)//2-1]+p[len(p)//2])/2))
        f = False
        for i in range(len(v)):
            if v[i] is not None and med[i] is not None and abs(v[i]-med[i])/med[i] > pct: v[i] = None; f = True
        if not f: break
    return np.array([y is not None for y in v])

def series(db, rr_col):
    t, rr = map(np.array, zip(*db.execute(f"select t_end_ms_est, {rr_col} from beat order by t_end_ms_est")))
    t, rr = t.astype(float), rr.astype(float)
    k = clean(list(rr))
    return t[k] - rr[k]/2, 60000/rr[k], int((~k).sum())

def fit(ht, h, s, e, P):
    k = (ht >= s) & (ht < e)
    if k.sum() < 12: return None
    tau = (ht[k]-s)/1000; y = h[k]; w = 2*math.pi/(P/1000)
    X = np.column_stack([np.ones_like(tau), tau, np.cos(w*tau), np.sin(w*tau)])
    b = np.linalg.lstsq(X, y, rcond=None)[0]; res = y - X@b
    tr = y - X[:, :2]@np.linalg.lstsq(X[:, :2], y, rcond=None)[0]
    return 2*math.hypot(b[2], b[3]), 1-(res@res)/(tr@tr), (math.atan2(b[3], b[2])/(2*math.pi)) % 1

C = series(chest, "rr_ms")
A = series(arm, "rr_1024")     # straplog-d1h: the armband's RR values are ms
ev = chest.execute("select at_ms, kind, note from event where kind like 'pacer%' order by at_ms").fetchall()
mot = np.array(arm.execute("select second_ms, gx_mg, gy_mg, gz_mg, rms_mg from motion order by second_ms").fetchall(), float)

def paced(t, t0, P, inh):
    x = ((t - t0) % P) / P
    return np.where(x < inh, (1 - np.cos(np.pi*x/inh))/2, (1 + np.cos(np.pi*(x-inh)/(1-inh)))/2)

for i, (at, kind, note) in enumerate(ev):
    if kind != "pacer_start": continue
    m = re.match(r"([\d.]+)/min in([\d.]+) out([\d.]+) t0=(\d+)", note)
    rate, t0 = float(m[1]), int(m[4]); inh = float(m[2])/(float(m[2])+float(m[3]))
    stop = next(a for a, kk, _ in ev[i+1:] if kk == "pacer_stop"); P = 60000/rate
    nc = ((C[0] >= t0) & (C[0] < stop)).sum(); na = ((A[0] >= t0) & (A[0] < stop)).sum()
    print(f"\n== {rate}/min, {(stop-t0)/60000:.1f} min · kept beats H10 {nc}, armband {na}")
    print("  window(s)   H10 swing sync peak  |  arm swing sync peak")
    rows = []
    b = 0
    while t0 + (b+4)*P <= stop:
        s, e = t0 + b*P, t0 + (b+4)*P
        c, a = fit(C[0], C[1], s, e, P), fit(A[0], A[1], s, e, P)
        rows.append((c, a))
        fa = f"{a[0]:5.1f} {a[1]:4.2f} {a[2]:.2f}" if a else "   no fit"
        print(f"  {(e-t0)/1000:5.0f}      {c[0]:5.1f} {c[1]:4.2f} {c[2]:.2f}  | {fa}")
        b += 1
    ok = [(c, a) for c, a in rows if c and a]
    ds = np.array([a[0]-c[0] for c, a in ok]); dy = np.array([a[1]-c[1] for c, a in ok])
    dp = np.array([((a[2]-c[2]+0.5) % 1)-0.5 for c, a in ok])
    print(f"  arm − H10: swing median {np.median(ds):+.2f} bpm (|Δ| median {np.median(abs(ds)):.2f}), "
          f"sync {np.median(dy):+.2f}, peak {np.median(dp):+.3f} breath; windows with arm fit {len(ok)}/{len(rows)}")

    # Arm breath: per-second gravity, band-passed around the pacer rate, principal axis, vs pacer.
    k = (mot[:, 0] >= t0) & (mot[:, 0] < stop)
    t, g = mot[k, 0], mot[k, 1:4]
    if len(t) < 60: print("  motion: too few seconds"); continue
    grid = np.arange(t[0], t[-1], 1000.0)
    gi = np.column_stack([np.interp(grid, t, g[:, j]) for j in range(3)])
    lo, hi = 0.5*rate/60, 1.6*rate/60
    sos = signal.butter(2, [lo, min(hi, 0.45)], btype="band", fs=1, output="sos")
    gb = signal.sosfiltfilt(sos, signal.detrend(gi, axis=0), axis=0)
    u, sv, vt = np.linalg.svd(gb - gb.mean(0), full_matrices=False)
    proj = gb @ vt[0]
    ref = paced(grid, t0, P, inh)
    lags = np.arange(-int(P/2000), int(P/2000)+1)
    rs = [np.corrcoef(np.roll(proj, -L)[abs(L):-abs(L) or None], ref[abs(L):-abs(L) or None])[0, 1] for L in lags]
    j = int(np.argmax(np.abs(rs)))
    f, Pw = signal.welch(signal.detrend(proj), fs=1, nperseg=min(len(proj), 128))
    print(f"  arm breath: swing {2*math.sqrt(2)*proj.std():.1f} mg, spectral peak {f[np.argmax(Pw)]*60:.1f}/min, "
          f"best |r| vs pacer {abs(rs[j]):.2f} at lag {lags[j]:+d} s (sign {'+' if rs[j] > 0 else '−'}), "
          f"median movement {np.median(mot[k, 4]):.1f} mg")
