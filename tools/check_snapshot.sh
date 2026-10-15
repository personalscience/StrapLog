#!/usr/bin/env bash
# Data checks on an exported StrapLog snapshot, with plain sqlite3 (docs/TESTING.md).
# Usage: tools/check_snapshot.sh <snapshot.sqlite> [recording_id]   (default: latest recording)
set -euo pipefail
db="$1"
q() { sqlite3 -batch -noheader "$db" "$1"; }
rid="${2:-$(q 'SELECT MAX(id) FROM recording')}"
fail=0
check() { # name, ok(0/1), detail
  if [[ "$2" == 1 ]]; then echo "PASS  $1  ($3)"; else echo "FAIL  $1  ($3)"; fail=1; fi
}

echo "recording $rid: $(q "SELECT name || ', ' || ROUND((ended_at_ms - started_at_ms)/60000.0, 1) || ' min' FROM recording WHERE id = $rid")"
[[ -e "$db-wal" || -e "$db-shm" ]] && check "no sidecars" 0 "found -wal/-shm" || check "no sidecars" 1 "single file"

back=$(q "SELECT COUNT(*) FROM (SELECT received_at_ms - LAG(received_at_ms) OVER (ORDER BY id) AS d
          FROM notification WHERE recording_id = $rid) WHERE d < 0")
check "monotonic received_at_ms" "$([[ $back == 0 ]] && echo 1 || echo 0)" "$back backwards steps"

read -r sum_s span_s <<<"$(q "SELECT (SELECT SUM(rr_ms) FROM beat WHERE recording_id = $rid)/1000.0,
                                     (MAX(received_at_ms) - MIN(received_at_ms))/1000.0
                              FROM notification WHERE recording_id = $rid" | tr '|' ' ')"
pct=$(awk -v a="$sum_s" -v b="$span_s" 'BEGIN { printf "%.2f", (b > 0 ? 100 * (a - b) / b : 999) }')
ok=$(awk -v p="$pct" 'BEGIN { print (p >= -1 && p <= 1) ? 1 : 0 }')
check "sum(rr) vs elapsed within 1%" "$ok" "Σrr ${sum_s}s vs span ${span_s}s → ${pct}%"

markers=$(q "SELECT COUNT(*) || ' [' || COALESCE(GROUP_CONCAT(note, ','), '') || ']' FROM event
             WHERE recording_id = $rid AND kind = 'marker'")
check "markers present" "$([[ ${markers%% *} -gt 0 ]] && echo 1 || echo 0)" "$markers"

two=$(q "SELECT COUNT(*) FROM notification WHERE recording_id = $rid AND n_rr >= 2")
check ">=1 notification with n_rr=2" "$([[ $two -gt 0 ]] && echo 1 || echo 0)" "$two notifications"

bad=$(q "SELECT COUNT(*) FROM notification n WHERE recording_id = $rid
         AND n_rr != (SELECT COUNT(*) FROM beat b WHERE b.notification_id = n.id)")
check "n_rr == count(beat)" "$([[ $bad == 0 ]] && echo 1 || echo 0)" "$bad mismatches"

echo "events: $(q "SELECT GROUP_CONCAT(kind, ' ') FROM (SELECT kind FROM event WHERE recording_id = $rid ORDER BY id)")"
exit $fail
