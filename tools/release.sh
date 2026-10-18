#!/usr/bin/env bash
# Archive StrapLog (iPhone app + Watch app + both widget extensions) and export it for the App Store.
# Usage: tools/release.sh            archive + export a signed .ipa to build/release/ (no upload)
#        tools/release.sh --upload   archive + upload to App Store Connect (TestFlight processing)
# Signing is automatic with Ensembio's cloud-managed distribution certificate: Xcode must be signed
# in to an Apple ID with Admin or Account Holder role on team 4RZ2RJUXC8.
# The build number is the git commit count (tools/stamp_build.sh), so the tree must be clean and
# each upload needs a new commit.
set -euo pipefail
cd "$(dirname "$0")/.."

destination=export
[[ "${1:-}" == --upload ]] && destination=upload

if [[ -n "$(git status --porcelain)" ]]; then
  echo "release.sh: working tree is dirty; commit first (the build number is the commit count)" >&2
  exit 1
fi

version=$(sed -n 's/^ *MARKETING_VERSION: "\(.*\)"/\1/p' project.yml)
build=$(git rev-list --count HEAD)
out=build/release/$version-$build
archive=$out/StrapLog.xcarchive
mkdir -p "$out"

xcodegen generate
xcodebuild -scheme StrapLog -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build/dd-release -archivePath "$archive" -allowProvisioningUpdates archive

# ASC rejects Apple product names in App Intent metadata (ITMS-90626, build 56: "iPhone").
if find "$archive" -path '*Metadata.appintents/extract.actionsdata' -exec grep -liE 'iphone|ipad|icloud|apple watch|siri' {} + ; then
  echo "release.sh: Apple product name in App Intent metadata (files above); ASC rejects it (ITMS-90626)" >&2
  exit 1
fi

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>$destination</string>
	<key>teamID</key><string>4RZ2RJUXC8</string>
	<key>signingStyle</key><string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key><false/>
	<key>uploadSymbols</key><true/>
</dict>
</plist>
EOF

# System PATH: the export's /usr/bin/rsync spawns `rsync` from PATH as its peer, and Homebrew's
# rsync 3.x rejects the -E it passes ("Copy failed").
PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$out/ExportOptions.plist" \
  -exportPath "$out" -allowProvisioningUpdates

echo "release.sh: $version ($build) $destination done → $out"
