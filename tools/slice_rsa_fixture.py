#!/usr/bin/env python3
"""Write Tests/fixtures/rsa-6.json: the follow_6 step of rsa-calibration.json (3 min at
6/min, from its pacer start) as a replay fixture (`-replay rsa-6 -speed 1`, then start the
pacer at 6/min by hand). ReplayHeartSource reads only `rr_ms`."""
import json
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent.parent / "Tests" / "fixtures"


def main() -> None:
    src = json.loads((FIXTURES / "rsa-calibration.json").read_text())
    step = next(s for s in src["steps"] if s["label"] == "follow_6")
    t0, end = step["pacer"]["t0_ms"], step["to_ms"]
    rr = [r for t, r in zip(src["t_end_ms"], src["rr_ms"]) if t0 <= t < end]
    out = {"source": {"fixture": "rsa-calibration.json", "step": "follow_6",
                      "breaths_per_minute": step["pacer"]["breaths_per_minute"]},
           "rr_ms": rr}
    (FIXTURES / "rsa-6.json").write_text(json.dumps(out, separators=(",", ":")) + "\n")
    print(f"rsa-6.json: {len(rr)} beats, {sum(rr) / 1000:.0f} s")


if __name__ == "__main__":
    main()
