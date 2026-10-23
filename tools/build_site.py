#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["markdown>=3.5"]
# ///
"""Build site/straplog/ from the page sources in site/src/ and the in-app Guide.

Each page source may use {{analytics}} (the shared GA4 tag in site/src/_analytics.html);
the docs page also takes {{guide}}. The web page renders the same Guide.md the app ships
(from "## Getting started" on), plus web-only edits. Each edit must find its anchor,
so a reworded Guide fails the build instead of silently dropping the edit. Guide images
(![caption](name.jpg), made by tools/guide_images.py) become figures from img/guide/.
"""
import html
import re
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "site/src"
SITE = ROOT / "site/straplog"
GUIDE = ROOT / "StrapLog/Resources/Guide.md"
PAGES = {"straplog.html": "index.html", "privacy.html": "privacy/index.html"}

START = "## Getting started"
IMAGE = re.compile(r"^!\[(.*)\]\(([^)/]+\.jpg)\)$", re.MULTILINE)
IMAGES = SITE / "img/guide"
WEB_EDITS = [
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
    text = IMAGE.sub(figure, text)
    # baselevel 2: the Guide's ## chapters sit under the page's <h2 id="guide"> as <h3>.
    return markdown.markdown(text, extensions=["tables", "toc"],
                             extension_configs={"toc": {"baselevel": 2}})


def figure(match: re.Match) -> str:
    caption, file = match.groups()
    if not (IMAGES / file).exists():
        raise SystemExit(f"Guide.md: {file} not in {IMAGES.relative_to(ROOT)}; run tools/guide_images.py")
    cap = markdown.markdown(caption).removeprefix("<p>").removesuffix("</p>")  # inline Markdown
    alt = html.escape(html.unescape(re.sub(r"<[^>]+>", "", cap)), quote=True)
    return (f'<figure class="shot"><img src="img/guide/{file}" alt="{alt}" loading="lazy">'
            f'<figcaption>{cap}</figcaption></figure>')


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
