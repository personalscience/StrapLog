# /// script
# dependencies = ["straplog>=0.4"]
# ///
"""Writes Tests/fixtures/rsa-calibration-summary.json (straplog-9fr.6): straplog-py's
`rsa.runs` over the rsa-calibration fixture's followed steps, one pacer run per step with a
real pacer (start = the reference window's start - SETTLE_MS, stop = its end). StrapLogCore's
`RSASummaryTests` and straplog-py's `test_rsa` both check against it, which is what holds the
app and the Python reader to the same numbers.

Usage: uv run tools/gen_rsa_summary.py
  (before a straplog release: uv run --no-project --with-editable ~/dev/straplog-py python tools/gen_rsa_summary.py)"""
import json
from pathlib import Path

from straplog import rsa

fixtures = Path(__file__).resolve().parent.parent / "Tests/fixtures"
fx = json.loads((fixtures / "rsa-calibration.json").read_text())
steps = [s for s in fx["steps"] if s["pacer"]]
sessions = [{"start_ms": s["reference"]["from_ms"] - rsa.SETTLE_MS, "stop_ms": s["reference"]["to_ms"],
             "rate": s["pacer"]["breaths_per_minute"], "t0_ms": s["pacer"]["t0_ms"]} for s in steps]
runs = rsa.runs(fx["t_end_ms"], fx["rr_ms"], sessions, end_ms=fx["t_end_ms"][-1])
keys = ("start_ms", "stop_ms", "rate", "t0_ms", "breaths", "breaths_valid", "windows", "windows_fitted",
        "swing_bpm", "sync", "peak_fraction")
out = [{"label": s["label"]} | {k: r[k] for k in keys} for s, r in zip(steps, runs, strict=True)]
(fixtures / "rsa-calibration-summary.json").write_text(json.dumps(out, indent=1) + "\n")
for r in out:
    print(f"{r['label']:11} {r['rate']:4g}/min  breaths {r['breaths_valid']:2}/{r['breaths']:2}  "
          f"fits {r['windows_fitted']:2}/{r['windows']:2}  swing {r['swing_bpm']:5.2f}  "
          f"sync {r['sync']:.3f}  peak {r['peak_fraction']:.3f}")
