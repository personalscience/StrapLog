# /// script
# requires-python = ">=3.11"
# dependencies = ["straplog>=0.3", "numpy", "pandas", "matplotlib"]
# ///
"""Agreement between two sensors worn at the same time: a reference (Polar H10,
StrapLog) and a test device (e.g. BaroShift armband, ArmLog).

Usage: uv run tools/compare_straps.py --ref H10.sqlite --test ARMBAND.sqlite [--out DIR]

Both apps ran on one phone, so beat timestamps share a clock. Receipt times
are jittery (BLE delivery, batched notifications), so each beat's time is
rebuilt from the exact RR sum plus a rolling median of the receipt offset.
Beats are paired by time alone (never by RR value, which would bias agreement
upward); windows are cleaned per device with straplog.hrv. Segments come from
the reference file's markers: sleep = lights_out → next BaroShift start (or
end), minus upright posture bouts; a BaroShift block is reported separately.
"""
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from straplog.hrv import clean_rr, dfa_alpha1, time_domain

WIN_S, STRIDE_S = 300, 60
PCT = 0.20                  # sleep/resting artifact threshold, as the skills use
MIN_BEATS = 150             # cleaned beats per 5-min window, per device
SMOOTH_BEATS = 61           # rolling window for the receipt-offset median
MATCH_TOL_MS = 300

THRESHOLDS = {  # fixed before looking at the data (plan, 2026-11-14)
    "hr_bias": 1.0, "hr_loa": 3.0, "rmssd_mape": 10.0, "rmssd_icc": 0.90,
    "night_lnrmssd": 0.10, "coverage": 95.0,
}


# ---------- loading ----------

def load(path: Path) -> dict:
    con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        rid, name, t0, t1, tz, dev = con.execute(
            "SELECT id,name,started_at_ms,ended_at_ms,tz_offset_s,device_id FROM recording "
            "ORDER BY started_at_ms DESC LIMIT 1").fetchone()
        beats = pd.read_sql_query(
            "SELECT t_end_ms_est AS t_est, rr_ms FROM beat WHERE recording_id=? ORDER BY id",
            con, params=(rid,))
        ev = pd.read_sql_query(
            "SELECT at_ms, kind, coalesce(label,'') AS label, coalesce(note,'') AS note "
            "FROM event WHERE recording_id=? ORDER BY at_ms", con, params=(rid,))
    finally:
        con.close()
    return dict(name=name, t0=t0, t1=t1, tz=tz, device=dev, beats=beats, events=ev)


def rebuild_times(b: pd.DataFrame) -> np.ndarray:
    """Beat times from cumsum(RR) + rolling median of (receipt − cumsum).
    Exact spacing inside runs; a gap (missed beats) steps the offset."""
    cs = np.cumsum(b["rr_ms"].to_numpy())
    resid = b["t_est"].to_numpy() - cs
    off = pd.Series(resid).rolling(SMOOTH_BEATS, center=True, min_periods=1).median().to_numpy()
    return cs + off


def local(ms, tz) -> str:
    return pd.to_datetime(ms + tz * 1000, unit="ms").strftime("%H:%M")


# ---------- alignment ----------

def hr_series(t, rr, t0, t1, fs=4.0):
    grid = np.arange(t0, t1, 1000 / fs)
    idx = np.searchsorted(t, grid)
    ok = (idx > 0) & (idx < len(t))
    hr = np.full(grid.size, np.nan)
    hr[ok] = 60000 / rr[idx[ok]]
    return grid, hr


def xcorr_lag(ref_t, ref_rr, tst_t, tst_rr, t0, t1, max_s=10) -> float:
    """Lag (ms) to subtract from test times so its HR best lines up with ref."""
    _, a = hr_series(ref_t, ref_rr, t0, t1)
    _, b = hr_series(tst_t, tst_rr, t0, t1)
    a = a - np.nanmean(a); b = b - np.nanmean(b)
    a = np.nan_to_num(a); b = np.nan_to_num(b)
    lags = np.arange(-max_s * 4, max_s * 4 + 1)
    c = [np.dot(a[max(0, -k):len(a) - max(0, k)], b[max(0, k):len(b) - max(0, -k)]) for k in lags]
    return float(lags[int(np.argmax(c))] * 250)


def match(ref_t, tst_t, tol=MATCH_TOL_MS):
    """Nearest test beat for each ref beat within tol; mutual-nearest only,
    then keep pairs whose neighbours on both sides are also consecutive pairs."""
    j = np.clip(np.searchsorted(tst_t, ref_t), 1, len(tst_t) - 1)
    j = np.where(np.abs(tst_t[j - 1] - ref_t) < np.abs(tst_t[j] - ref_t), j - 1, j)
    ok = np.abs(tst_t[j] - ref_t) <= tol
    # mutual nearest: test beat j's nearest ref beat must be this one
    i_back = np.clip(np.searchsorted(ref_t, tst_t[j]), 1, len(ref_t) - 1)
    i_back = np.where(np.abs(ref_t[i_back - 1] - tst_t[j]) < np.abs(ref_t[i_back] - tst_t[j]),
                      i_back - 1, i_back)
    ok &= i_back == np.arange(len(ref_t))
    ri = np.flatnonzero(ok); tj = j[ok]
    cons = (np.diff(ri) == 1) & (np.diff(tj) == 1)
    keep = np.zeros(len(ri), bool)
    keep[1:-1] = cons[:-1] & cons[1:]
    return ri[keep], tj[keep]


# ---------- stats ----------

def agreement(ref, tst) -> dict:
    ref, tst = np.asarray(ref, float), np.asarray(tst, float)
    m = np.isfinite(ref) & np.isfinite(tst)
    ref, tst = ref[m], tst[m]
    if ref.size < 3:
        return dict(n=int(ref.size))
    d = tst - ref
    x = np.c_[ref, tst]; n = len(x); mean = x.mean()
    msr = 2 * ((x.mean(1) - mean) ** 2).sum() / (n - 1)
    msc = n * ((x.mean(0) - mean) ** 2).sum() / 1
    sse = ((x - x.mean(1, keepdims=True) - x.mean(0) + mean) ** 2).sum()
    mse = sse / (n - 1)
    icc = (msr - mse) / (msr + mse + 2 * (msc - mse) / n)
    return dict(n=n, ref_mean=ref.mean(), tst_mean=tst.mean(), bias=d.mean(),
                loa=1.96 * d.std(ddof=1), mae=np.abs(d).mean(),
                mape=100 * np.mean(np.abs(d) / np.abs(ref)), r=np.corrcoef(ref, tst)[0, 1], icc=icc)


def windows(dev_t, dev_rr, t0, t1):
    rows = []
    for c in np.arange(t0 + WIN_S * 500, t1 - WIN_S * 500 + 1, STRIDE_S * 1000):
        lo, hi = c - WIN_S * 500, c + WIN_S * 500
        raw = dev_rr[(dev_t >= lo) & (dev_t < hi)]
        clean = clean_rr(raw, PCT) if raw.size else raw
        row = dict(t=c, n_raw=raw.size, n=clean.size)
        if clean.size >= MIN_BEATS:
            td = time_domain(clean)
            row |= dict(hr=60000 / td["mean_rr_ms"], rmssd=td["rmssd_ms"], ln_rmssd=td["ln_rmssd"],
                        sdnn=td["sdnn_ms"], pnn50=td["pnn50_pct"], alpha1=dfa_alpha1(clean))
        rows.append(row)
    return pd.DataFrame(rows)


# ---------- segments ----------

def segments(ev: pd.DataFrame, t0, t1) -> dict:
    """Sleep and BaroShift intervals from the reference markers."""
    lo = ev.loc[ev.label == "lights_out", "at_ms"]
    bs = ev[ev.note.str.contains("BaroShift", case=False)]
    bs_start = bs.loc[bs.note.str.contains("start", case=False), "at_ms"]
    bs_end = bs.loc[bs.note.str.contains("end", case=False), "at_ms"]
    sleep_lo = int(lo.iloc[0]) if len(lo) else t0
    later = bs_start[bs_start > sleep_lo]
    sleep_hi = int(later.iloc[0]) if len(later) else t1
    upright, open_at = [], None
    for _, e in ev[ev.kind == "posture"].iterrows():
        if e.note == "upright":
            open_at = e.at_ms
        elif open_at is not None:
            upright.append((open_at, e.at_ms)); open_at = None
    if open_at is not None:
        upright.append((open_at, t1))
    segs = {"overlap": [(t0, t1)], "sleep": [(max(sleep_lo, t0), min(sleep_hi, t1))]}
    for s, e in zip(bs_start, bs_end):
        if e > t0 and s < t1:
            segs.setdefault("baroshift", []).append((max(s, t0), min(e, t1)))
    segs["_upright"] = upright
    return segs


def in_segment(t, spans, upright=(), whole_window=False):
    t = np.asarray(t)
    half = WIN_S * 500 if whole_window else 0
    m = np.zeros(t.shape, bool)
    for s, e in spans:
        m |= (t - half >= s) & (t + half <= e)
    for s, e in upright:
        m &= ~((t + half >= s) & (t - half <= e))
    return m


# ---------- main ----------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True, type=Path)
    ap.add_argument("--test", required=True, type=Path)
    ap.add_argument("--out", type=Path)
    a = ap.parse_args()

    R, T = load(a.ref), load(a.test)
    tz = R["tz"]
    out = a.out or Path("build/compare") / pd.to_datetime(R["t0"] + tz * 1000, unit="ms").strftime("%Y-%m-%d")
    out.mkdir(parents=True, exist_ok=True)

    rt, rr = rebuild_times(R["beats"]), R["beats"]["rr_ms"].to_numpy()
    tt, tr = rebuild_times(T["beats"]), T["beats"]["rr_ms"].to_numpy()
    t0, t1 = max(R["t0"], T["t0"]) + 60_000, min(R["t1"], T["t1"]) - 60_000
    lines = [f"# {R['device']} (ref) vs {T['device']} (test) — {R['name']}",
             f"Overlap {local(t0, tz)}–{local(t1, tz)} ({(t1 - t0) / 3.6e6:.2f} h)", ""]

    # lag, coarse then per-hour refinement on matched pairs
    lag = xcorr_lag(rt, rr, tt, tr, t0, t1)
    tt_al = tt - lag
    ri, tj = match(rt, tt_al, tol=600)
    resid = pd.Series(tt_al[tj] - rt[ri], index=rt[ri])
    hourly = resid.groupby(((resid.index - t0) // 3.6e6).astype(int)).median()
    lag += float(resid.median())
    tt_al = tt - lag
    lines += [f"Lag (test − ref): {lag:+.0f} ms; hourly residual medians (ms): "
              + ", ".join(f"{v:+.0f}" for v in hourly.to_numpy()), ""]

    segs = segments(R["events"], t0, t1)
    up = segs.pop("_upright")
    ri, tj = match(rt, tt_al)
    pairs = pd.DataFrame({"t": rt[ri], "ref": rr[ri], "tst": tr[tj]})
    pairs["d_ref"] = np.r_[np.nan, np.diff(pairs.ref)]
    pairs["d_tst"] = np.r_[np.nan, np.diff(pairs.tst)]
    pairs.loc[np.r_[True, np.diff(ri) != 1] | np.r_[True, np.diff(tj) != 1], ["d_ref", "d_tst"]] = np.nan

    # beat-level table
    lines += ["## Beats", "", "| segment | ref beats | matched % | test extra | RR bias ms | RR MAE ms | RR LoA ± ms | within 20 ms % | ΔRR r | longest test gap s |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for name, spans in segs.items():
        rm = in_segment(rt, spans, up if name == "sleep" else ())
        tm = in_segment(tt_al, spans, up if name == "sleep" else ())
        pm = in_segment(pairs.t, spans, up if name == "sleep" else ())
        p = pairs[pm]
        d = p.tst - p.ref
        dd = p[["d_ref", "d_tst"]].dropna()
        gaps = np.diff(tt_al)[tm[:-1] & tm[1:]]   # only between beats both inside the segment
        gap = gaps.max() / 1000 if gaps.size else np.nan
        cov = 100 * pm.sum() / max(rm.sum(), 1)
        extra = tm.sum() - pm.sum()
        lines.append(f"| {name} | {rm.sum()} | {cov:.1f} | {extra} | {d.mean():+.1f} | {d.abs().mean():.1f} | "
                     f"{1.96 * d.std():.0f} | {100 * (d.abs() <= 20).mean():.1f} | "
                     f"{np.corrcoef(dd.d_ref, dd.d_tst)[0, 1]:.3f} | {gap:.0f} |")
        if name == "sleep":
            sleep_cov = cov

    # window-level table
    wr = windows(rt, rr, t0, t1).add_prefix("r_")
    wt = windows(tt_al, tr, t0, t1).add_prefix("t_")
    w = pd.concat([wr, wt], axis=1).rename(columns={"r_t": "t"}).drop(columns="t_t")
    w.to_csv(out / "windows.csv", index=False)
    lines += ["", f"## 5-min windows ({STRIDE_S}s stride, cleaned per device, pct {PCT})", "",
              "| segment | metric | n | ref mean | test mean | bias | LoA ± | MAE | MAPE % | r | ICC |",
              "|---|---|---|---|---|---|---|---|---|---|---|"]
    stats = {}
    for name, spans in segs.items():
        wm = w[in_segment(w.t, spans, up if name == "sleep" else (), whole_window=True)]
        for met in ("hr", "rmssd", "ln_rmssd", "sdnn", "pnn50", "alpha1"):
            if f"r_{met}" not in wm:
                continue
            s = agreement(wm[f"r_{met}"], wm[f"t_{met}"])
            stats[(name, met)] = s
            if s["n"] < 3:
                continue
            lines.append(f"| {name} | {met} | {s['n']} | {s['ref_mean']:.2f} | {s['tst_mean']:.2f} | "
                         f"{s['bias']:+.2f} | {s['loa']:.2f} | {s['mae']:.2f} | {s['mape']:.1f} | "
                         f"{s['r']:.3f} | {s['icc']:.3f} |")
        n_valid = wm[["r_hr", "t_hr"]].notna().all(axis=1).sum() if "t_hr" in wm else 0
        lines.append(f"| {name} | windows both valid / total | {n_valid} / {len(wm)} | | | | | | | | |")

    # whole-night summary (sleep segment)
    sp = segs["sleep"]
    night = {}
    for lab, t, x, wp in (("ref", rt, rr, "r_"), ("test", tt_al, tr, "t_")):
        m = in_segment(t, sp, up)
        raw = x[m]; clean = clean_rr(raw, PCT); td = time_domain(clean)
        wm = w[in_segment(w.t, sp, up, whole_window=True)]
        night[lab] = dict(beats=raw.size, artifact_pct=100 * (1 - clean.size / max(raw.size, 1)),
                          hr_mean=60000 / td["mean_rr_ms"], hr_min5=wm[f"{wp}hr"].min(),
                          rmssd_night=td["rmssd_ms"], ln_rmssd_night=td["ln_rmssd"],
                          rmssd_5min_median=wm[f"{wp}rmssd"].median(), sdnn_night=td["sdnn_ms"])
    lines += ["", f"## Sleep period {local(sp[0][0], tz)}–{local(sp[0][1], tz)} (upright bouts excluded)", "",
              "| | ref | test |", "|---|---|---|"]
    for k in night["ref"]:
        lines.append(f"| {k} | {night['ref'][k]:.2f} | {night['test'][k]:.2f} |")

    # verdict
    hr, rm = stats[("sleep", "hr")], stats[("sleep", "rmssd")]
    checks = [
        ("HR bias ≤ ±1 bpm", abs(hr["bias"]) <= THRESHOLDS["hr_bias"], f"{hr['bias']:+.2f}"),
        ("HR LoA ≤ ±3 bpm", hr["loa"] <= THRESHOLDS["hr_loa"], f"±{hr['loa']:.2f}"),
        ("RMSSD MAPE ≤ 10 %", rm["mape"] <= THRESHOLDS["rmssd_mape"], f"{rm['mape']:.1f} %"),
        ("RMSSD ICC ≥ 0.90", rm["icc"] >= THRESHOLDS["rmssd_icc"], f"{rm['icc']:.3f}"),
        ("night lnRMSSD within ±0.10", abs(night["test"]["ln_rmssd_night"] - night["ref"]["ln_rmssd_night"])
         <= THRESHOLDS["night_lnrmssd"], f"{night['test']['ln_rmssd_night'] - night['ref']['ln_rmssd_night']:+.3f}"),
        ("beat coverage ≥ 95 %", sleep_cov >= THRESHOLDS["coverage"], f"{sleep_cov:.1f} %"),
    ]
    lines += ["", "## Verdict (sleep period, thresholds fixed in advance)", "",
              "| check | value | pass |", "|---|---|---|"]
    lines += [f"| {c} | {v} | {'✅' if ok else '❌'} |" for c, ok, v in checks]

    text = "\n".join(lines)
    (out / "summary.md").write_text(text + "\n")
    print(text)
    plots(out, w, pairs, rt, rr, tt_al, tr, segs, R["events"], tz, stats)
    print(f"\nWrote {out}/summary.md, windows.csv, *.png")


def plots(out, w, pairs, rt, rr, tt, tr, segs, ev, tz, stats):
    hrs = lambda ms: (np.asarray(ms) - w.t.iloc[0]) / 3.6e6
    fig, ax = plt.subplots(3, 1, figsize=(13, 9), sharex=True)
    for met, a, lab in (("hr", ax[0], "HR bpm"), ("rmssd", ax[1], "RMSSD ms"), ("alpha1", ax[2], "DFA α1")):
        a.plot(hrs(w.t), w[f"r_{met}"], lw=1, label="H10 (ref)")
        a.plot(hrs(w.t), w[f"t_{met}"], lw=1, label="armband (test)")
        a.set_ylabel(lab)
    for _, e in ev[ev.kind == "marker"].iterrows():
        for a in ax:
            a.axvline(hrs(e.at_ms), color="grey", lw=0.6, ls=":")
        ax[0].text(hrs(e.at_ms), ax[0].get_ylim()[1], e.label or e.note, fontsize=7, rotation=90, va="top")
    ax[0].legend(loc="upper right"); ax[2].set_xlabel(f"hours from {local(w.t.iloc[0], tz)}")
    fig.tight_layout(); fig.savefig(out / "trajectory.png", dpi=130); plt.close(fig)

    sp, up = segs["sleep"], ()
    wm = w[in_segment(w.t, sp, up, whole_window=True)]
    fig, ax = plt.subplots(1, 2, figsize=(12, 5))
    for a, met, lab in ((ax[0], "hr", "HR bpm"), (ax[1], "rmssd", "RMSSD ms")):
        x, y = wm[f"r_{met}"], wm[f"t_{met}"]
        mean, d = (x + y) / 2, y - x
        s = stats[("sleep", met)]
        a.scatter(mean, d, s=6, alpha=0.5)
        for v, ls in ((s["bias"], "-"), (s["bias"] + s["loa"], "--"), (s["bias"] - s["loa"], "--")):
            a.axhline(v, color="k", ls=ls, lw=0.8)
        a.set_title(f"{lab}: bias {s['bias']:+.2f}, LoA ±{s['loa']:.2f}, ICC {s['icc']:.3f}")
        a.set_xlabel("mean of devices"); a.set_ylabel("armband − H10")
    fig.tight_layout(); fig.savefig(out / "bland_altman.png", dpi=130); plt.close(fig)

    zooms = [("sleep", sp[0][0] + (sp[0][1] - sp[0][0]) * 0.4)]
    if "baroshift" in segs:
        zooms.append(("BaroShift", segs["baroshift"][0][0] + 180_000))
    fig, ax = plt.subplots(len(zooms), 1, figsize=(13, 3.5 * len(zooms)), squeeze=False)
    for a, (lab, c) in zip(ax[:, 0], zooms):
        lo, hi = c, c + 120_000
        for t, x, n in ((rt, rr, "H10"), (tt, tr, "armband")):
            m = (t >= lo) & (t < hi)
            a.plot((t[m] - lo) / 1000, x[m], marker="o", ms=3, lw=0.8, label=n)
        a.set_title(f"{lab} zoom, {local(lo, tz)} + 2 min"); a.set_ylabel("RR ms"); a.legend()
    ax[-1, 0].set_xlabel("s")
    fig.tight_layout(); fig.savefig(out / "rr_zoom.png", dpi=130); plt.close(fig)


if __name__ == "__main__":
    main()
