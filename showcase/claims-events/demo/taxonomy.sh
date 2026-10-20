#!/usr/bin/env bash
# What the event taxonomy does for the system-level declaration. The workspace is
# copied to a temporary directory; nothing here is modified.
#   1. As committed: the root declares publishes [claim:ClaimEvent]; the containers
#      publish eleven specific events. No finding at the root.
#   2. Without the ontology's relations: { publishes: { lift: range-lcs } } block:
#      the drift output is byte-identical (in v0.1.0 the comparison uses is-a
#      subsumption whether or not the relation opts in to the lift).
#   3. With one is-a link cut (FloodClaimFiled no longer under PropertyClaimFiled):
#      the flood event is no longer a ClaimEvent, and both the intake container
#      and the system exceed their declarations.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
export GLOSS_ACTOR=agent:claude-code

echo "== 1. as committed: root findings"
"$GLOSS" drift --fail-on none > "$TMP/committed.txt" || true
grep -c "claimb:claims-events " "$TMP/committed.txt" || true

echo
echo "== 2. relations: lift removed from ontology/claim.gloss.yaml"
sed -i '/^  produces: { lift: range-lcs }$/d; /^  consumes: { lift: range-lcs }$/d; /^  publishes: { lift: range-lcs }$/d; /^  subscribes: { lift: range-lcs }$/d' ontology/claim.gloss.yaml
"$GLOSS" build -q
"$GLOSS" drift --fail-on none > "$TMP/nolift.txt" || true
if diff -q "$TMP/committed.txt" "$TMP/nolift.txt" >/dev/null; then echo "drift output identical"; else diff "$TMP/committed.txt" "$TMP/nolift.txt"; fi

echo
echo "== 3. FloodClaimFiled cut out of the taxonomy (is-a: PropertyClaimFiled -> kind: event)"
python3 - <<'PY'
from pathlib import Path
p = Path("ontology/claim.gloss.yaml"); s = p.read_text()
old = '  FloodClaimFiled:\n    is-a: PropertyClaimFiled\n'
assert old in s
p.write_text(s.replace(old, '  FloodClaimFiled:\n    kind: event\n'))
PY
"$GLOSS" build -q
"$GLOSS" drift --fail-on none | sed -n '/Violations/,/^$/p'
