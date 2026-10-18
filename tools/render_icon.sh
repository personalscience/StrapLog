#!/usr/bin/env bash
# Render design/AppIcon.svg into the phone and Watch asset catalogs' single 1024 px app icon (needs rsvg-convert).
set -euo pipefail
cd "$(dirname "$0")/.."
rsvg-convert -w 1024 -h 1024 -b white design/AppIcon.svg -o StrapLog/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
cp StrapLog/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png StrapLogWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
