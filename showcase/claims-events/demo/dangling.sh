#!/usr/bin/env bash
# Why this workspace documents no dangling finding: in v0.1.0 a marker whose target
# does not exist is a gloss check error (GM215), and the showcase contract requires
# gloss check to pass. The workspace is copied to a temporary directory.
#   1. subscribes claim:ClaimReopened (no such concept): check fails, drift reports dangling.
#   2. the same link written as a proposal of a new concept (claim:NEW:ClaimReopened):
#      check passes and drift reports a rogue concept, a decision for the core owner.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
export GLOSS_ACTOR=agent:claude-code
F=services/payout-notifier/internal/consumer/consumer.go

echo "== 1. // @gloss subscribes claim:ClaimReopened"
sed -i 's|^// Run polls until ctx is cancelled.|// @gloss subscribes claim:ClaimReopened\n&|' "$F"
"$GLOSS" check || echo "(gloss check exit $?)"
"$GLOSS" build -q
"$GLOSS" drift --fail-on none | sed -n '/Dangling/,/^$/p'

echo "== 2. // @gloss? subscribes claim:NEW:ClaimReopened conf=0.6"
sed -i 's|^// @gloss subscribes claim:ClaimReopened|// @gloss? subscribes claim:NEW:ClaimReopened conf=0.6 note="reopened claims should pause the payout email"|' "$F"
"$GLOSS" check || echo "(gloss check exit $?)"
"$GLOSS" build -q
"$GLOSS" drift --fail-on none | sed -n '/Rogue/,/^$/p'
