#!/usr/bin/env bash
# Xcode build phase: stamps the built Info.plist with `StrapLogCommit` (short sha, `-dirty` when the
# tree has uncommitted changes) and `StrapLogBuiltAt` (local time), shown in the Strap sheet so a
# recording can be tied to the build that made it. Never fails the build.
set -uo pipefail
plist="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
sha=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
[[ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]] && sha="$sha-dirty"
built=$(date '+%Y-%m-%d %H:%M')
for kv in "StrapLogCommit:$sha" "StrapLogBuiltAt:$built"; do
  key=${kv%%:*} val=${kv#*:}
  /usr/libexec/PlistBuddy -c "Set :$key $val" "$plist" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$key string $val" "$plist"
done
exit 0
