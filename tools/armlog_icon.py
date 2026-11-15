#!/usr/bin/env python3
"""Derive ArmLog's icon SVGs from StrapLog's (design/icon/straplog-ios-*.svg).

StrapLog's mark is a strap: a rounded body with two thin arms. ArmLog drops the arms and stretches
the body across the full icon width, as an armband reads. The tubes and pulse stay centred; the
pulse's flat ends stretch to the widened window. Writes design/icon/armlog-ios-{light,dark,tinted}.svg;
tools/render_icon.sh rasterises them into ArmLog's asset catalog.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "design/icon"

MARGIN = 40          # outer edge of the body's stroke, as far in as StrapLog's arm tips
BODY_STROKE = 46
WINDOW_INSET = 53    # body rect to inner window rect, as in StrapLog
WINDOW_STROKE = 14
PULSE_CAP = 10       # half the pulse's stroke: its round cap reaches this far past the end point


def armlog(svg: str) -> str:
    # Drop the two arms: the only rects at y=464.
    svg, n = re.subn(r'<rect x="[\d.]+" y="464\.0" width="228\.0" height="96" rx="48\.0" fill="[^"]+"/>', "", svg)
    assert n == 2, f"expected 2 arms, found {n}"

    body_x = MARGIN + BODY_STROKE / 2
    body_w = 1024 - 2 * body_x
    svg, n = re.subn(r'<rect x="222\.0" y="342\.0" width="580"', f'<rect x="{body_x}" y="342.0" width="{body_w}"', svg)
    assert n == 1, "body rect not found"

    win_x = body_x + WINDOW_INSET
    win_w = body_w - 2 * WINDOW_INSET
    svg, n = re.subn(r'<rect x="275\.0" y="395\.0" width="474"', f'<rect x="{win_x}" y="395.0" width="{win_w}"', svg)
    assert n == 1, "window rect not found"

    # Stretch the pulse's flat ends so its caps meet the window's inner edge, as in StrapLog.
    start = win_x + WINDOW_STROKE / 2 + PULSE_CAP
    end = 1024 - start
    def stretch(m: re.Match) -> str:
        pts = m.group(1)
        return f'<polyline points="{start},539.4 {pts} {end},539.4"'
    svg, n = re.subn(r'<polyline points="([^"]+)"', stretch, svg)
    assert n == 1, "pulse polyline not found"
    return svg


for look in ("light", "dark", "tinted"):
    src = (ICONS / f"straplog-ios-{look}.svg").read_text()
    (ICONS / f"armlog-ios-{look}.svg").write_text(armlog(src))
    print(f"wrote design/icon/armlog-ios-{look}.svg")
