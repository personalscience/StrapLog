#!/usr/bin/env bash
# Render design/icon/*.svg into the asset catalogs' 1024 px app icons (needs rsvg-convert):
# the phone's light, dark and tinted appearances, and the Watch's single icon. Also copies the
# complication template into the Watch widgets' catalog as the vector `StrapMark`.
# The SVGs carry their own backgrounds; tinted is transparent on purpose.
set -euo pipefail
cd "$(dirname "$0")/.."
phone=StrapLog/Resources/Assets.xcassets/AppIcon.appiconset
watch=StrapLogWatch/Resources/Assets.xcassets/AppIcon.appiconset
for look in light dark tinted; do
    rsvg-convert -w 1024 -h 1024 "design/icon/straplog-ios-$look.svg" -o "$phone/AppIcon-$look.png"
done
rsvg-convert -w 1024 -h 1024 design/icon/straplog-watch.svg -o "$watch/AppIcon.png"
cp design/icon/straplog-complication-template.svg StrapLogWatchWidgets/Assets.xcassets/StrapMark.imageset/StrapMark.svg
