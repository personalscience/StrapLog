#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=10"]
# ///
"""Make the Guide's illustrations from the App Store screenshots.

Reads build/screenshots/*.png (tools/screenshots.sh) and the tracked Watch PNGs, downscales each
to at most 600 px wide as JPEG q80, and writes them twice: an imageset per picture in
StrapLog/Resources/GuideImages.xcassets (the app) and site/straplog/img/guide/ (the web page).
Guide.md refers to them as ![caption](name.jpg). Both outputs are rebuilt from scratch, so a
picture dropped from IMAGES disappears from both.
"""
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "StrapLog/Resources/GuideImages.xcassets"
SITE = ROOT / "site/straplog/img/guide"
WIDTH = 600
QUALITY = 80

# Guide name -> source PNG. Keep to 8 or fewer (the app grows by their size).
IMAGES = {
    "guide-home": "build/screenshots/05-home.png",
    "guide-recording": "build/screenshots/01-recording.png",
    "guide-alpha1": "build/screenshots/02-alpha1.png",
    "guide-pacer": "build/screenshots/04-pacer.png",
    "guide-detail": "build/screenshots/03-detail.png",
    "guide-watch-recording": "design/screenshots/watch/3-recording-mark.png",
    "guide-watch-no-iphone": "design/screenshots/watch/1-idle.png",
}

CATALOG = {"info": {"author": "xcode", "version": 1}}


def jpeg(src: Path, dst: Path) -> None:
    with Image.open(src) as im:
        im = im.convert("RGB")
        if im.width > WIDTH:
            im = im.resize((WIDTH, round(im.height * WIDTH / im.width)), Image.LANCZOS)
        im.save(dst, "JPEG", quality=QUALITY, optimize=True, progressive=True)


def main() -> None:
    missing = [s for s in IMAGES.values() if not (ROOT / s).exists()]
    if missing:
        raise SystemExit(f"missing {missing}; run tools/screenshots.sh first")
    for out in (ASSETS, SITE):
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
    (ASSETS / "Contents.json").write_text(json.dumps(CATALOG, indent=2) + "\n")

    total = 0
    for name, src in IMAGES.items():
        web = SITE / f"{name}.jpg"
        jpeg(ROOT / src, web)
        imageset = ASSETS / f"{name}.imageset"
        imageset.mkdir()
        shutil.copy(web, imageset / web.name)
        contents = {"images": [{"filename": web.name, "idiom": "universal"}], **CATALOG}
        (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
        size = web.stat().st_size
        total += size
        print(f"{name:24} {size // 1024:4} KB")
    print(f"{'total':24} {total // 1024:4} KB")


if __name__ == "__main__":
    main()
