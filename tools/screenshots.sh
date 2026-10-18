#!/usr/bin/env bash
# Capture the App Store iPhone screenshots (6.9", 1320×2868) from a real-time replay.
# Runs StrapLogUITests/AppStoreScreenshots (~4 min) and exports its PNGs to build/screenshots/.
# Watch screenshots come from a real Watch (side button + Digital Crown).
set -euo pipefail
cd "$(dirname "$0")/.."

device="iPhone 17 Pro Max"
out=build/screenshots
result=build/screenshots.xcresult
rm -rf "$out" "$result"
mkdir -p "$out"

xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl status_bar "$device" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi
trap 'xcrun simctl status_bar "$device" clear' EXIT

xcodegen generate
TEST_RUNNER_STRAPLOG_SCREENSHOTS=1 xcodebuild test -scheme StrapLog \
  -destination "platform=iOS Simulator,name=$device" -derivedDataPath build/dd \
  -only-testing:StrapLogUITests/AppStoreScreenshots -resultBundlePath "$result"

xcrun xcresulttool export attachments --path "$result" --output-path "$out"
# Name each PNG after its attachment (01-recording.png, ...).
python3 - "$out" <<'PY'
import json, pathlib, sys
out = pathlib.Path(sys.argv[1])
for test in json.loads((out / "manifest.json").read_text()):
    for a in test["attachments"]:
        name = a.get("suggestedHumanReadableName", "")
        stem = name.split("_")[0] if name else ""
        if stem[:2].isdigit():
            (out / a["exportedFileName"]).rename(out / f"{stem}.png")
PY
ls -1 "$out"/*.png
