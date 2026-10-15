#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "pandas"]
# ///
"""Generate HRVKit parity fixtures from an HRV Logger DB.sqlite.

Expected metrics are computed by importing the skill's own analyze_h10.py,
never re-derived here, so HRVKit is tested against the code the skills run.

    tools/gen_fixtures.py --db ~/Downloads/hrv260420/DB.sqlite --pk 4 --name resting

Writes Tests/fixtures/<name>.json:
    source       db path, pk, recording name
    constants    the analyze_h10 constants the numbers were made with
    t_rel_s      beat timestamps, seconds since first beat, rounded to 1 ms
    rr_ms        raw RR intervals
    clean        whole-recording clean_rr(): removed indices + summary metrics
    windows      rolling_features() rows plus SDNN (ddof=1) per window
t_rel is rounded *before* the reference is computed, so the fixture is
self-consistent: Swift sees exactly the inputs Python saw.
"""
from __future__ import annotations

import argparse
import json
import sys
import types
from pathlib import Path

import numpy as np
import pandas as pd

SKILL_SCRIPTS = Path.home() / "dev/skills/h10-session/skills/h10-session/scripts"
REPO = Path(__file__).resolve().parent.parent


def import_analyze_h10():
    # analyze_h10 imports chart_style (plotnine) at module load; stub it so the
    # fixture tool needs only numpy + pandas.
    sys.modules.setdefault("chart_style", types.ModuleType("chart_style"))
    sys.path.insert(0, str(SKILL_SCRIPTS))
    import analyze_h10  # noqa: E402
    return analyze_h10


def none_if_nan(x: float) -> float | None:
    return None if x is None or not np.isfinite(x) else float(x)


def removed_indices(raw: np.ndarray, pct_thresh: float, a) -> list[int]:
    """Indices clean_rr() drops. Recomputed with clean_rr's own steps because
    clean_rr returns only survivors; checked against clean_rr below."""
    x = raw.astype(float).copy()
    x[(x < 300) | (x > 2000)] = np.nan
    for _ in range(3):
        s = pd.Series(x)
        med = s.rolling(5, center=True, min_periods=3).median()
        bad = (s - med).abs() / med > pct_thresh
        if not bad.any():
            break
        x[bad.values] = np.nan
    idx = np.flatnonzero(np.isnan(x))
    survivors = np.delete(raw.astype(float), idx)
    assert np.array_equal(survivors, a.clean_rr(raw, pct_thresh)), "removed-index drift"
    return idx.tolist()


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--db", type=Path, required=True)
    p.add_argument("--pk", type=int, required=True)
    p.add_argument("--name", required=True, help="fixture name, e.g. resting")
    p.add_argument("--out", type=Path, default=REPO / "Tests/fixtures")
    args = p.parse_args()

    a = import_analyze_h10()
    rr_df, _ev, _start, rec_name = a.load_recording(args.db.expanduser(), args.pk)
    rr_df = rr_df.assign(t_rel=rr_df["t_rel"].round(3))
    raw = rr_df["rr_ms"].to_numpy(dtype=float)
    pct = a.PCT_THRESH_DEFAULT

    clean = a.clean_rr(raw, pct)
    d = np.diff(clean)
    feat = a.rolling_features(rr_df, a.WINDOW_SEC_DEFAULT, a.STRIDE_SEC_DEFAULT, pct)

    t_arr, windows = rr_df["t_rel"].to_numpy(), []
    for _, w in feat.iterrows():
        lo = w.t_center - a.WINDOW_SEC_DEFAULT / 2
        hi = w.t_center + a.WINDOW_SEC_DEFAULT / 2
        wc = a.clean_rr(raw[(t_arr >= lo) & (t_arr < hi)], pct)
        windows.append({
            "t_center_s": float(w.t_center),
            "n_raw": int(w.n_raw),
            "n_beats": int(w.n_beats),
            "hr_bpm": float(w.hr_bpm),
            "rmssd_ms": none_if_nan(w.rmssd),
            "sdnn_ms": float(np.std(wc, ddof=1)),
            "alpha1": none_if_nan(w.alpha1),
        })

    fixture = {
        "source": {"db": str(args.db), "pk": args.pk, "recording": rec_name},
        "constants": {
            "window_s": a.WINDOW_SEC_DEFAULT, "stride_s": a.STRIDE_SEC_DEFAULT,
            "pct_thresh": pct, "min_beats_per_window": a.MIN_BEATS_PER_WIN,
            "dfa_scale_min": a.DFA_SCALE_MIN, "dfa_scale_max": a.DFA_SCALE_MAX,
            "sdnn_ddof": 1,
        },
        "t_rel_s": rr_df["t_rel"].tolist(),
        "rr_ms": [int(v) if float(v).is_integer() else float(v) for v in raw],
        "clean": {
            "removed_indices": removed_indices(raw, pct, a),
            "n_clean": int(clean.size),
            "rmssd_ms": float(np.sqrt((d ** 2).mean())),
            "sdnn_ms": float(np.std(clean, ddof=1)),
            "mean_hr_bpm": float(60000.0 / clean.mean()),
            "alpha1": none_if_nan(a.dfa_alpha1(clean)),
        },
        "windows": windows,
    }
    args.out.mkdir(parents=True, exist_ok=True)
    out = args.out / f"{args.name}.json"
    out.write_text(json.dumps(fixture, separators=(",", ":")) + "\n")
    print(f"{out.relative_to(REPO)}: {len(raw)} beats, {len(windows)} windows, "
          f"{len(fixture['clean']['removed_indices'])} removed, {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
