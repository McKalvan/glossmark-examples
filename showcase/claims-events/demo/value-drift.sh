#!/usr/bin/env bash
# The documented value-drift and the two ways to resolve it. The workspace is
# copied to a temporary git repository and committed as the before-state;
# nothing in this directory is modified.
#   As committed: Thresholds.kt says 0.75, the ontology still publishes "0.80".
#   A. The business agrees to 0.75: change value: in the ontology. Drift clears;
#      gloss diff makes the change HARD (an edit to a published concept).
#   B. Confirm the code as is with gloss accept --value --force: drift clears, the
#      ontology still says 0.80 (the baseline moved, the published value did not).
#      Without --force, accept refuses a line that does not hold the published
#      value, although drift's hint names the command without it (GlossMark #174).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
git init -q
git add -A
git -c user.name=demo -c user.email=demo@example.invalid commit -qm before
export GLOSS_ACTOR=agent:claude-code

echo "== as committed"
"$GLOSS" drift --fail-on none | grep -A1 'Published values drifted'

echo
echo "== A. value: \"0.80\" -> \"0.75\" in ontology/tide.gloss.yaml"
sed -i 's/^    value: "0.80"$/    value: "0.75"/' ontology/tide.gloss.yaml
"$GLOSS" build -q
"$GLOSS" drift --fail-on none | grep -c 'Published values drifted' || true
"$GLOSS" diff --base HEAD --fail-on none | grep -E 'gate|FraudReferral' || true

git checkout -q -- ontology/tide.gloss.yaml .glossmark
echo
echo "== B. gloss accept --value tide:FraudReferralPolicy (refused), then with --force"
"$GLOSS" accept --value tide:FraudReferralPolicy || true
"$GLOSS" accept --value --force tide:FraudReferralPolicy
"$GLOSS" build -q
"$GLOSS" drift --fail-on none | grep -c 'Published values drifted' || true
grep -A1 '^  FraudReferralPolicy:' ontology/tide.gloss.yaml >/dev/null && grep '^    value: "0.80"' ontology/tide.gloss.yaml
