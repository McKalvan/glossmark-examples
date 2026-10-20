#!/usr/bin/env bash
# Run the documented-drift contract on one showcase workspace:
#   1. gloss check reports 0 errors and its output matches expected-check.txt
#   2. gloss drift --fail-on <kinds> passes (kinds that must never appear here)
#   3. the full drift output matches expected-drift.txt
#   4. the committed graph and ledger are current (gloss build changes nothing)
# Usage: scripts/check-workspace.sh <workspace-root> <fail-on kinds>
# UPDATE=1 rewrites the golden files instead of comparing.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
ws="$1"; fail_on="$2"
# gloss v0.1.0 accepts unknown kinds in --fail-on silently, so a typo would disable the gate.
KINDS=" violation gap value-drift dangling rogue orphan untested presented-only stale proposed none "
for k in ${fail_on//,/ }; do
  case "$KINDS" in *" $k "*) ;; *) echo "::error::$ws: unknown finding kind '$k' in fail-on"; exit 2 ;; esac
done
cd "$ROOT/$ws" || { echo "no workspace $ws"; exit 2; }
out="$ROOT/.ci-out/${ws//\//_}"; mkdir -p "$out"
status=0

"$GLOSS" check >"$out/check.txt" 2>&1
rc=$?
if [ $rc -ne 0 ]; then echo "::error::$ws: gloss check failed (exit $rc)"; cat "$out/check.txt"; status=1; fi

"$GLOSS" drift --fail-on "$fail_on" >"$out/drift.txt" 2>"$out/drift.err"
rc=$?
if [ $rc -ne 0 ]; then echo "::error::$ws: gloss drift --fail-on $fail_on failed"; cat "$out/drift.err"; status=1; fi

for f in check drift; do
  if [ "${UPDATE:-}" = 1 ]; then
    cp "$out/$f.txt" "expected-$f.txt"
  elif ! diff -u "expected-$f.txt" "$out/$f.txt"; then
    echo "::error::$ws: gloss $f output differs from expected-$f.txt; update the documented-drift table and the golden file together"
    status=1
  fi
done

if [ "${UPDATE:-}" != 1 ]; then
  before=$(cat .glossmark/graph.jsonl .glossmark/ledger.jsonl 2>/dev/null | sha256sum)
  "$GLOSS" build -q >"$out/build.txt" 2>&1
  after=$(cat .glossmark/graph.jsonl .glossmark/ledger.jsonl | sha256sum)
  if [ "$before" != "$after" ]; then
    echo "::error::$ws: .glossmark/ was not current; run gloss build and commit graph.jsonl and ledger.jsonl"
    git --no-pager diff --stat -- .glossmark 2>/dev/null || true
    status=1
  fi
fi

[ $status -eq 0 ] && echo "ok  $ws"
exit $status
