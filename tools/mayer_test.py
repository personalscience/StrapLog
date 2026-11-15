# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "scipy", "matplotlib"]
# ///
"""Mayer-wave test: does the armband's forearm PPG carry a ~0.1 Hz rhythm that
is not breathing, heart-rate swing or movement?

Usage: uv run tools/mayer_test.py --band BAND.sqlite --h10 H10.sqlite [--out DIR]

Protocol (one session, both apps on one phone, so one clock): the band
recording's own pacer events and markers mark three blocks, paced 10/min
(breathing at 0.167 Hz, clear of 0.1 Hz), free breathing, paced 6/min
(breathing on top of 0.1 Hz). Paced blocks run pacer_start → pacer_stop; the
free block runs from the marker after the first pacer_stop to the next marker.
The first SETTLE_S of each block is dropped.

Series, each resampled to 4 Hz:
  rr    H10 R-R (ms), from stored beats, 20 % median-deviation cleaning
  amp   PPG pulse amplitude per beat (trough-to-peak of the band-passed wave)
  base  PPG baseline (raw low-passed below 0.4 Hz), the slow blood-volume level
  move  accelerometer |a| − 1 g RMS per second (mg). On the armband this sits near
        60 mg at rest, an offset from its inferred 4096 counts/g scale, so it
        carries movement only in its changes.
The PPG is flipped (−raw) so pulses peak upward, as the app draws it.

Per block and series: Welch spectrum, power in the Mayer band (0.07–0.13 Hz)
against the mean of its flanks (0.04–0.065 and 0.135–0.16 Hz, minus the
breathing band; revised after the first run, see mayer_ratio). Then amp and base are regressed on rr (lags
±5 s) and move, and the residual's Mayer peak is reported.

Verdict rule, fixed before running: in the 10/min block, a residual Mayer
peak ≥ 3× background in amp or base means the forearm sees a 0.1 Hz rhythm
the H10's R-R does not explain. Otherwise "vasomotor" there is breathing plus
heart-rate swing.
"""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

import numpy as np
from scipy import signal
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

FS = 4.0                    # resampled series, Hz
PPG_HZ = 32.0
OFF_SKIN = 32767
SETTLE_S = 20
MAYER = (0.07, 0.13)
FLANKS = [(0.04, 0.065), (0.135, 0.16)]
BREATH_HALF_WIDTH = 0.02
PEAK_RATIO = 3.0
LAG_S = 5
WELCH_S = 100


def blocks(band: sqlite3.Connection) -> list[tuple[str, float, float, float | None]]:
    """(name, start_ms, end_ms, breathing Hz or None) from the band file's pacer events."""
    ev = band.execute("SELECT kind, at_ms, note FROM event ORDER BY at_ms").fetchall()
    starts = [(t, n) for k, t, n in ev if k == "pacer_start"]
    stops = [t for k, t, _ in ev if k == "pacer_stop"]
    markers = [t for k, t, _ in ev if k == "marker"]
    if len(starts) != 2 or len(stops) < 2:
        raise SystemExit(f"expected two pacer blocks, found starts={len(starts)} stops={len(stops)}")
    out = []
    for (t0, note), t1 in zip(starts, stops):
        rate = float(note.split("/")[0])
        out.append((f"paced {rate:g}/min", t0, t1, rate / 60))
    free0 = next(t for t in markers if t > stops[0])
    free1 = next(t for t in markers if t > free0)
    out.insert(1, ("free", free0, free1, None))
    return [(n, a + SETTLE_S * 1000, b, f) for n, a, b, f in out]


def ppg_times(band: sqlite3.Connection) -> tuple[np.ndarray, np.ndarray]:
    """PPG on an even clock: the packet counter (unwrapped, lost packets kept as gaps) gives
    each reading's index, and a straight-line fit of receipt time on index gives its time."""
    rows = band.execute("SELECT received_at_ms, counter, value FROM ppg ORDER BY received_at_ms").fetchall()
    # Packets arrive in bursts sharing a millisecond, and a burst can straddle the counter's
    # wrap (254, 255, 0, 1), so order each burst by its distance from the previous counter.
    ordered, prev, i = [], rows[0][1] - 1, 0
    while i < len(rows):
        j = i
        while j < len(rows) and rows[j][0] == rows[i][0]:
            j += 1
        burst = sorted(rows[i:j], key=lambda r: (r[1] - prev) % 256)
        ordered += burst
        prev, i = burst[-1][1], j
    t_rx, ctr, val = np.array(ordered, float).T
    step = np.diff(ctr) % 256
    step[step == 0] = 256       # a full wrap between two packets: rare, but keep order
    idx = np.concatenate([[0], np.cumsum(step)])
    a, b = np.polyfit(idx, t_rx, 1)
    print(f"PPG: {len(val)} readings, {1000 / a:.2f} Hz by fit, {int(idx[-1] + 1 - len(val))} lost")
    return a * idx + b, val


def resample(t_ms: np.ndarray, v: np.ndarray, grid_ms: np.ndarray) -> np.ndarray:
    return np.interp(grid_ms, t_ms, v)


def ppg_series(t_ms: np.ndarray, raw: np.ndarray, grid_ms: np.ndarray) -> tuple[np.ndarray, np.ndarray, int]:
    ok = raw != OFF_SKIN
    t_ms, x = t_ms[ok], -raw[ok]
    even = np.arange(t_ms[0], t_ms[-1], 1000 / PPG_HZ)
    x = np.interp(even, t_ms, x)
    base = signal.sosfiltfilt(signal.butter(2, 0.4, "low", fs=PPG_HZ, output="sos"), x)
    pulse = signal.sosfiltfilt(signal.butter(2, [0.5, 4.0], "band", fs=PPG_HZ, output="sos"), x)
    peaks, _ = signal.find_peaks(pulse, distance=int(PPG_HZ * 0.33), prominence=np.std(pulse) * 0.3)
    amps, times = [], []
    for p0, p1 in zip(peaks, peaks[1:]):
        trough = p0 + np.argmin(pulse[p0:p1])
        amps.append(pulse[p1] - pulse[trough])
        times.append(even[p1])
    amps, times = np.array(amps), np.array(times)
    med = signal.medfilt(amps, 9)
    keep = np.abs(amps - med) < 0.5 * med
    in_block = (times >= grid_ms[0]) & (times <= grid_ms[-1])
    return (resample(times[keep], amps[keep], grid_ms), resample(even, base, grid_ms),
            int(in_block.sum()))


def rr_series(h10: sqlite3.Connection, grid_ms: np.ndarray) -> np.ndarray:
    t, rr = np.array(h10.execute("SELECT t_end_ms_est, rr_ms FROM beat ORDER BY id").fetchall(), float).T
    global h10_beats
    h10_beats = int(((t >= grid_ms[0]) & (t <= grid_ms[-1])).sum())
    med = signal.medfilt(rr, 11)
    keep = np.abs(rr - med) < 0.2 * med
    return resample(t[keep], rr[keep], grid_ms)


def move_series(band: sqlite3.Connection, grid_ms: np.ndarray) -> np.ndarray:
    t, m = np.array(band.execute("SELECT second_ms + 500, rms_mg FROM motion ORDER BY second_ms").fetchall(), float).T
    return resample(t, m, grid_ms)


def spectrum(x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    x = signal.detrend(x)
    n = min(len(x), int(WELCH_S * FS))
    return signal.welch(x, fs=FS, nperseg=n, noverlap=n // 2, detrend="linear")


def mayer_ratio(f: np.ndarray, p: np.ndarray, breath_hz: float | None) -> float:
    """Peak power in the Mayer band over the mean of its flanks (FLANKS, minus the breathing
    band). Revised after the first run: a median over 0.03–0.25 Hz flattered the PPG baseline,
    whose spectrum falls steeply with frequency, so any bump looked like a 100× peak."""
    in_band = (f >= MAYER[0]) & (f <= MAYER[1])
    bg = np.zeros_like(f, bool)
    for lo, hi in FLANKS:
        bg |= (f >= lo) & (f <= hi)
    if breath_hz:
        bg &= np.abs(f - breath_hz) > BREATH_HALF_WIDTH
    return float(p[in_band].max() / p[bg].mean())


def residual(y: np.ndarray, rr: np.ndarray, move: np.ndarray) -> tuple[np.ndarray, float]:
    """y minus its least-squares fit on rr at lags ±LAG_S and on move; also the R²."""
    lags = range(-int(LAG_S * FS), int(LAG_S * FS) + 1)
    z = lambda v: (v - v.mean()) / (v.std() or 1)
    cols = [np.roll(z(rr), k) for k in lags] + [z(move), np.ones_like(y)]
    pad = int(LAG_S * FS)
    X, yy = np.column_stack(cols)[pad:-pad], y[pad:-pad]
    beta, *_ = np.linalg.lstsq(X, yy, rcond=None)
    res = yy - X @ beta
    return res, 1 - res.var() / yy.var()


def peak_hz(f: np.ndarray, p: np.ndarray, lo: float, hi: float) -> float:
    m = (f >= lo) & (f <= hi)
    return float(f[m][np.argmax(p[m])])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--band", required=True, type=Path)
    ap.add_argument("--h10", required=True, type=Path)
    ap.add_argument("--out", type=Path, default=Path("build/mayer"))
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    band, h10 = sqlite3.connect(args.band), sqlite3.connect(args.h10)

    t_ppg, raw = ppg_times(band)
    bl = blocks(band)
    fig, axes = plt.subplots(len(bl), 3, figsize=(13, 3.2 * len(bl)), squeeze=False)
    print(f"\n{'block':<15}{'breath Hz':>10}{'series':>8}{'Mayer/bg':>10}{'resid/bg':>10}{'R² rr+mv':>10}"
          f"{'coh 0.1':>9}{'pulses':>7}{'H10':>6}{'move mg':>9}")
    verdict = []
    for row, (name, a, b, breath) in enumerate(bl):
        grid = np.arange(a, b, 1000 / FS)
        rr = rr_series(h10, grid)
        amp, base, n_beats = ppg_series(t_ppg, raw, grid)
        move = move_series(band, grid)
        f_rr, p_rr = spectrum(rr)
        breath_shown = breath or peak_hz(f_rr, p_rr, 0.13, 0.4)
        for col, (label, y) in enumerate([("rr", rr), ("amp", amp), ("base", base)]):
            f, p = spectrum(y)
            ratio = mayer_ratio(f, p, breath_shown)
            if label == "rr":
                rratio, r2, coh = float("nan"), float("nan"), float("nan")
            else:
                res, r2 = residual(y, rr, move)
                fr, pr = spectrum(res)
                rratio = mayer_ratio(fr, pr, breath_shown)
                fc, c = signal.coherence(y, rr, fs=FS, nperseg=min(len(y), int(WELCH_S * FS)))
                coh = float(c[(fc >= MAYER[0]) & (fc <= MAYER[1])].mean())
                if breath and breath > 0.15:
                    verdict.append((label, rratio))
                axes[row][col].semilogy(fr, pr, color="0.5", lw=1, label="residual")
            print(f"{name:<15}{breath_shown:>10.3f}{label:>8}{ratio:>10.1f}{rratio:>10.1f}{r2:>10.2f}"
                  f"{coh:>9.2f}{n_beats:>7}{h10_beats:>6}{move.mean():>9.1f}")
            ax = axes[row][col]
            ax.semilogy(f, p, lw=1.5, label=label)
            ax.axvspan(*MAYER, color="orange", alpha=0.15)
            ax.axvline(breath_shown, color="steelblue", ls="--", lw=1)
            ax.set_xlim(0.02, 0.4)
            ax.set_title(f"{name} — {label}", fontsize=9)
            ax.legend(fontsize=7)
    for ax in axes[-1]:
        ax.set_xlabel("Hz")
    fig.tight_layout()
    png = args.out / "mayer_spectra.png"
    fig.savefig(png, dpi=120)

    hit = [(l, r) for l, r in verdict if r >= PEAK_RATIO]
    print("\nVerdict (10/min block, residual Mayer peak ≥ "
          f"{PEAK_RATIO:g}× background): "
          + ("YES — " + ", ".join(f"{l} {r:.1f}×" for l, r in hit) if hit
             else "NO — " + ", ".join(f"{l} {r:.1f}×" for l, r in verdict)))
    print(f"Plot: {png}")


if __name__ == "__main__":
    main()
