# /// script
# dependencies = []
# ///
"""Writes Tests/fixtures/<name>.json: a stretch of per-second gravity (motion.gx/gy/gz_mg) plus
the pacer that ran over it, for BreathTrackerTests (straplog-cef).

Usage: gen_breath_fixture.py EXPORT.sqlite --from MS --to MS --name NAME"""
import argparse, json, re, sqlite3
from pathlib import Path

ap = argparse.ArgumentParser()
ap.add_argument("db"); ap.add_argument("--from", dest="a", type=int, required=True)
ap.add_argument("--to", dest="b", type=int, required=True); ap.add_argument("--name", required=True)
args = ap.parse_args()
db = sqlite3.connect(args.db)
rid, rec = db.execute("select id, name from recording").fetchone()
note = db.execute("select note from event where recording_id=? and kind='pacer_start' and at_ms<=? "
                  "order by at_ms desc limit 1", (rid, args.a)).fetchone()[0]
m = re.match(r"([\d.]+)/min in([\d.]+) out([\d.]+) t0=(\d+)", note)
rows = db.execute("select second_ms, gx_mg, gy_mg, gz_mg from motion where recording_id=? and second_ms>=? "
                  "and second_ms<? order by second_ms", (rid, args.a, args.b)).fetchall()
out = {"source": {"db": Path(args.db).name, "recording": rec, "from_ms": args.a, "to_ms": args.b},
       "pacer": {"breaths_per_minute": float(m[1]), "inhale_s": float(m[2]), "exhale_s": float(m[3]),
                 "t0_ms": int(m[4])},
       "second_ms": [r[0] for r in rows], "gx_mg": [r[1] for r in rows], "gy_mg": [r[2] for r in rows],
       "gz_mg": [r[3] for r in rows]}
path = Path(__file__).resolve().parent.parent / "Tests/fixtures" / f"{args.name}.json"
path.write_text(json.dumps(out, separators=(",", ":")))
print(f"{path}: {len(rows)} seconds, pacer {note}")
