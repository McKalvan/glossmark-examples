#!/usr/bin/env bash
# What happens across the three repositories when shipment-core changes a published
# concept. Each sibling is copied into a temporary directory and becomes its own git
# repository, as it will once GlossMark can fetch imports remotely. Nothing in this
# directory is modified.
#   1. shipment-core shortens the published delivery window (2h -> 90m): gloss diff is HARD
#   2. the importers notice: gloss check warns GM116 (content changed under the same version) and keeps the pinned copy
#   3. shipment-core bumps shc: to 1.1.1; the importers see GM116 (new version), re-pin with gloss lock --update
#   4. the own-subject rule: dispatch tries to add a part to an imported concept (GM400, GM401)
#   5. the published seam: tracking references an unpublished shc: concept (GM230)
#   6. shipment-core retypes a core concept and bumps frt: to 2.0.0: MAJOR, HARD; importers GM116 (outside their range, still on the pin)
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GLOSS_ACTOR=agent:claude-code
for r in shipment-core dispatch tracking; do
  cp -r "$HERE/$r" "$TMP/$r"
  git -C "$TMP/$r" init -q
  git -C "$TMP/$r" add -A
  git -C "$TMP/$r" -c user.name=demo -c user.email=demo@example.invalid commit -qm before
done
commit() { git -C "$TMP/$1" add -A; git -C "$TMP/$1" -c user.name=demo -c user.email=demo@example.invalid commit -qm "$2"; }
say() { printf '\n## %s\n' "$*"; }
run() { local repo=$1; shift; printf '\n%s$ %s\n' "$repo" "$*"; (cd "$TMP/$repo" && "$@"); local rc=$?; [ $rc -eq 0 ] || echo "(exit $rc)"; }
g() { local repo=$1; shift; run "$repo" gloss "$@"; }
gloss() { "$GLOSS" "$@"; }
core=shipment-core
WINDOW=service/src/main/java/com/kestrelfreight/shipment/booking/DeliveryWindowPolicy.java

say "1. shipment-core shortens the published delivery window, code and ontology together"
sed -i 's/WINDOW_LENGTH = Duration.ofHours(2);/WINDOW_LENGTH = Duration.ofMinutes(90);/' "$TMP/$core/$WINDOW"
sed -i 's/^    value: "2h"$/    value: "90m"/' "$TMP/$core/ontology/shc.gloss.yaml"
"$GLOSS" build -q --root "$TMP/$core"
g $core diff --base HEAD

say "2. the importers, before shipment-core bumps its version"
g dispatch check
g tracking check

say "3. shipment-core releases shc: 1.1.1; the importers review and re-pin"
sed -i 's/^version: 1.1.0$/version: 1.1.1/' "$TMP/$core/ontology/shc.gloss.yaml"
sed -i 's/tier: implementation, version: 1.1.0/tier: implementation, version: 1.1.1/' "$TMP/$core/glossmark.yaml"
"$GLOSS" build -q --root "$TMP/$core"
g $core diff --base HEAD --fail-on none | grep -E '^Version|bump'
commit $core "shc 1.1.1: delivery window 90m"
g dispatch check
g dispatch lock --update
g dispatch check
run dispatch git --no-pager diff --unified=0 glossmark.lock
g dispatch diff --base HEAD
g tracking lock --update
run tracking grep -n 'DELIVERY_WINDOW: Duration' src/delivery/window.rs
g tracking impact tests/window.rs
commit dispatch "re-pin shc 1.1.1"; commit tracking "re-pin shc 1.1.1"

say "4. the own-subject rule: dispatch may extend frt:, never mutate it"
cp "$TMP/dispatch/ontology/dsp.gloss.yaml" "$TMP/dsp.bak"
cat >> "$TMP/dispatch/ontology/dsp.gloss.yaml" <<'YAML'
  PickupManifest: { kind: entity, internal: true, has-part: [frt:Parcel] }
  frt:ExpressPickup: { is-a: frt:Pickup }
YAML
g dispatch check
cp "$TMP/dsp.bak" "$TMP/dispatch/ontology/dsp.gloss.yaml"

say "5. the published seam: only published shc: concepts cross repositories"
sed -i '1s|^|// @gloss verifies shc:LabelSpec, shc:LabelRenderer scope=file\n|' "$TMP/tracking/tests/scan_parse.rs"
sed -i 's|^allowed: \[derived, shc:DeliveryWindowPolicy\]|allowed: [derived, shc:DeliveryWindowPolicy, shc:LabelSpec, shc:LabelRenderer]|' "$TMP/tracking/.gloss.yaml"
g tracking check
echo; echo "# the same reference after shipment-core drops tier: implementation from shc.gloss.yaml (tracking re-pinned)"
sed -i '/^tier: implementation$/d' "$TMP/$core/ontology/shc.gloss.yaml"
"$GLOSS" lock --update --root "$TMP/tracking" >/dev/null
g tracking check
git -C "$TMP/$core" checkout -q -- ontology/shc.gloss.yaml
git -C "$TMP/tracking" checkout -q -- tests/scan_parse.rs .gloss.yaml glossmark.lock

say "6. a MAJOR change: frt:Tracking becomes a capability, frt: goes to 2.0.0"
sed -i '/^  Tracking:$/{n;s/kind: process/kind: capability/}' "$TMP/$core/ontology/frt.gloss.yaml"
sed -i 's/^version: 1.4.0$/version: 2.0.0/' "$TMP/$core/ontology/frt.gloss.yaml"
sed -i 's/tier: core,           version: 1.4.0/tier: core,           version: 2.0.0/' "$TMP/$core/glossmark.yaml"
"$GLOSS" build -q --root "$TMP/$core"
g $core diff --base HEAD
g dispatch check
g tracking check
