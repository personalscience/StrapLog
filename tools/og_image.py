#!/usr/bin/env -S uv run --script
# Social preview card site/straplog/img/og.png. Run from the repo root after tools/screenshots.sh: tools/og_image.py .
# /// script
# dependencies = ["pillow"]
# ///
import sys
from PIL import Image, ImageDraw, ImageFont
root = sys.argv[1]
W, H = 1200, 630
im = Image.new("RGB", (W, H), "#f4f6f7")
d = ImageDraw.Draw(im)
def font(size, bold=False):
    for p in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            f = ImageFont.truetype(p, size)
            if bold:
                try: f.set_variation_by_name("Bold")
                except Exception: pass
            return f
        except OSError: continue
icon = Image.open(f"{root}/site/straplog/icon.png").convert("RGBA").resize((140, 140))
im.paste(icon, (72, 90), icon)
d.text((72, 260), "StrapLog HRV", font=font(76, True), fill="#15191d")
for i, line in enumerate(["Every heartbeat from your chest strap,", "in a file you own."]):
    d.text((72, 360 + i * 46), line, font=font(38), fill="#4f5760")
d.text((72, 500), "Polar H10 · iPhone · Apple Watch", font=font(28), fill="#d63a3a")
shot = Image.open(f"{root}/build/screenshots/01-recording.png").convert("RGB")
shot = shot.crop((0, 0, shot.width, int(shot.width * 1.25))).resize((420, 525))
mask = Image.new("L", shot.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, *shot.size), 28, fill=255)
im.paste(shot, (W - 420 - 72, 52), mask)
im.save(f"{root}/site/straplog/img/og.png", optimize=True)
