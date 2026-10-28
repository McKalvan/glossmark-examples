#!/usr/bin/env bash
# What happens when the interlibrary-loan waiver in glossmark.yaml runs out.
# The workspace is copied to a temporary directory and the waiver's expiry is
# changed there. Nothing in this directory is modified.
#   1. as committed (expires 2027-06-30): the gap is listed, waived, and passes
#   2. expires 2026-06-30, a date in the past: the gap fails drift
#   3. expires written as "30 June 2020": not an ISO date, and still waived
#   4. no expires at all: still waived
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
FAIL_ON=violation,gap,value-drift,dangling,rogue,stale
show() {
  printf '\n$ gloss drift --fail-on %s   # %s\n' "$FAIL_ON" "$1"
  "$GLOSS" drift --fail-on "$FAIL_ON" 2>&1 | grep -E -A2 '^○ Gaps|failed:' | grep -v -E '^--$|^○|^  → '
  "$GLOSS" drift --fail-on "$FAIL_ON" >/dev/null 2>&1; echo "exit $?"
}
show "expires: 2027-06-30 (committed)"
sed -i 's/expires: 2027-06-30/expires: 2026-06-30/' glossmark.yaml
show "expires: 2026-06-30"
printf '\n$ gloss check | tail -1   # check does not mention the expired waiver\n'; "$GLOSS" check 2>&1 | tail -1
sed -i 's/expires: 2026-06-30/expires: 30 June 2020/' glossmark.yaml
show "expires: 30 June 2020"
sed -i 's/, expires: 30 June 2020//' glossmark.yaml
show "no expires"
