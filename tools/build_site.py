#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["markdown>=3.5"]
# ///
"""Build site/straplog/ from the page sources in site/src/ and the in-app Guide.

Each page source may use {{analytics}} (the shared GA4 tag in site/src/_analytics.html);
the docs page also takes {{guide}}. The web page renders the same Guide.md the app ships
(from "## Getting started" on), plus two web-only edits. Each edit must find its anchor,
so a reworded Guide fails the build instead of silently dropping the edit.
"""
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "site/src"
SITE = ROOT / "site/straplog"
GUIDE = ROOT / "StrapLog/Resources/Guide.md"
PAGES = {"straplog.html": "index.html", "privacy.html": "privacy/index.html"}

START = "## Getting started"
WEB_EDITS = [
    ("\n### Reinstalling",
     "\nFor ready-made analyses — overnight reports, workout summaries, threshold tests — see"
     " [Analyze it](#analyze) above: a Python package and open-source Claude skills that read"
     " these files directly. The experiments I run with them go out in the"
     " [Personal Science newsletter](#newsletter), one a month.\n\n### Reinstalling"),
    ("Include it if you contact support.",
     "Include it when you write to [support@personalscience.com](mailto:support@personalscience.com?subject=StrapLog)."),
]


def guide_html() -> str:
    text = GUIDE.read_text()
    text = text[text.index(START):]
    for anchor, replacement in WEB_EDITS:
        if text.count(anchor) != 1:
            raise SystemExit(f"Guide.md: expected one {anchor!r}; update WEB_EDITS")
        text = text.replace(anchor, replacement)
    # baselevel 2: the Guide's ## chapters sit under the page's <h2 id="guide"> as <h3>.
    return markdown.markdown(text, extensions=["tables", "toc"],
                             extension_configs={"toc": {"baselevel": 2}})


def fill(page: str, name: str, slots: dict[str, str]) -> str:
    for key, value in slots.items():
        marker = "{{" + key + "}}"
        if key == "analytics" and page.count(marker) != 1:
            raise SystemExit(f"{name}: expected one {marker}")
        page = page.replace(marker, value)
    if "{{" in page:
        raise SystemExit(f"{name}: unfilled placeholder")
    return page


def main() -> None:
    slots = {"analytics": (SRC / "_analytics.html").read_text().strip(), "guide": guide_html()}
    for src, out in PAGES.items():
        path = SITE / out
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(fill((SRC / src).read_text(), src, slots))
        print(f"wrote {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
