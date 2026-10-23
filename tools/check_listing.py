#!/usr/bin/env python3
"""Check docs/APPSTORE.md listing fields against App Store Connect limits and the no-Polar-marks rule."""
import re
import sys
from pathlib import Path

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100, "promo": 170, "description": 4000, "whatsnew": 4000}
# Polar's marks may appear only in the description's single compatibility line (straplog-kzk.3).
MARKS = re.compile(r"polar|h10", re.IGNORECASE)

text = (Path(__file__).resolve().parent.parent / "docs/APPSTORE.md").read_text()
fields = dict(re.findall(r"<!-- listing:(\w+) -->\n(.*?)\n<!-- /listing -->", text, re.DOTALL))

errors = []
for name, limit in LIMITS.items():
    value = fields.get(name)
    if value is None:
        errors.append(f"{name}: missing")
        continue
    print(f"{name:12} {len(value):5} / {limit}")
    if len(value) > limit:
        errors.append(f"{name}: {len(value)} chars, limit {limit}")
    marked = [line for line in value.splitlines() if MARKS.search(line)]
    allowed = 1 if name == "description" else 0
    if len(marked) > allowed:
        errors.append(f"{name}: Polar/H10 on {len(marked)} lines, allowed {allowed}")

keywords = fields.get("keywords", "")
if ", " in keywords:
    errors.append("keywords: no spaces after commas (they count against the limit)")

for error in errors:
    print("ERROR", error, file=sys.stderr)
sys.exit(1 if errors else 0)
