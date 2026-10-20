#!/usr/bin/env bash
# Run gloss landscape over sibling workspaces and compare with expected-landscape.txt.
# Usage: scripts/check-landscape.sh <example-dir> <fail-on kinds> <repo>...
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
dir="$1"; fail_on="$2"; shift 2
cd "$ROOT/$dir" || exit 2
out="$ROOT/.ci-out/${dir//\//_}"; mkdir -p "$out"
status=0
"$GLOSS" landscape --fail-on "$fail_on" "$@" >"$out/landscape.txt" 2>"$out/landscape.err" \
  || { echo "::error::$dir: gloss landscape --fail-on $fail_on failed"; cat "$out/landscape.err"; status=1; }
if [ "${UPDATE:-}" = 1 ]; then
  cp "$out/landscape.txt" expected-landscape.txt
elif ! diff -u expected-landscape.txt "$out/landscape.txt"; then
  echo "::error::$dir: landscape output differs from expected-landscape.txt"; status=1
fi
[ $status -eq 0 ] && echo "ok  $dir (landscape)"
exit $status
