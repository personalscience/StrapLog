#!/usr/bin/env bash
# Xcode build phase: stamps the built Info.plist with `StrapLogCommit` (short sha, `-dirty` when the
# tree has uncommitted changes) and `StrapLogBuiltAt` (local time), shown in the Strap sheet so a
# recording can be tied to the build that made it. Also sets `CFBundleVersion` to the commit count,
# so the build number rises with every commit without editing a tracked file. Never fails the build.
set -uo pipefail
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
sha=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
[[ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]] && sha="$sha-dirty"
built=$(date '+%Y-%m-%d %H:%M')
build=$(git -C "$SRCROOT" rev-list --count HEAD 2>/dev/null || echo 1)
for kv in "CFBundleVersion:$build" "StrapLogCommit:$sha" "StrapLogBuiltAt:$built"; do
  key=${kv%%:*} val=${kv#*:}
  /usr/libexec/PlistBuddy -c "Set :$key $val" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$key string $val" "$plist"
done
exit 0
