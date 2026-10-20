#!/usr/bin/env bash
# The review lifecycle on a copy of this workspace in a temporary git repository.
# Nothing in this directory is modified.
#   accept --concept  the menu-curator's proposed pepper:MenuAvailability (refused until it realizes something)
#   reject --concept  the order-flow-engineer's rogue SplitBill, after propose --from-new lifts it
#   removed           the order-flow-engineer withdraws its ticket-bump-route proposal
#   export --prov     who did what, as PROV-O
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
# Print the command as typed (gloss for the binary, quotes kept), then run it.
step() {
  local shown="gloss" a
  for a in "${@:2}"; do case "$a" in *" "*) shown+=" \"$a\"" ;; *) shown+=" $a" ;; esac; done
  printf '\n$ %s\n' "$shown"
  "$@" 2>&1
}
ledger() { jq -c "select(.marker_id==\"$1\") | {marker_id, status, actor, reviewed_by, rationale}" .glossmark/ledger.jsonl; }

# 1. Accept the proposed concept. accept --concept wants realizes: although gloss check
#    accepts the part-of the committed entry carries; the reviewer adds it, then accepts.
step "$GLOSS" accept --concept pepper:MenuAvailability || true
sed -i 's|^    part-of: MenuCatalog .*|    part-of: MenuCatalog\n    realizes: dine:MenuPublishing|' ontology/pepper.gloss.yaml
step "$GLOSS" accept --concept pepper:MenuAvailability

# 2. Lift the rogue SplitBill into a proposed concept, then reject it. Flags go before
#    the CURIE: after it they are not parsed and --reason reads as missing.
GLOSS_ACTOR=agent:order-flow-engineer step "$GLOSS" propose --from-new --doc "Splitting one bill into several payments at the table."
step "$GLOSS" reject --concept --reason "Tillpoint splits the bill at the terminal; one payment per order stays" --remove pepper:SplitBill

# 3. Withdraw a proposal by deleting its marker line.
sed -i '/id=ticket-bump-route/d' api/ordering/routers/tickets.py
"$GLOSS" build -q

printf '\n$ jq ... .glossmark/ledger.jsonl   # the rows these steps wrote\n'
ledger concept:pepper:MenuAvailability
ledger concept:pepper:SplitBill
ledger ticket-bump-route
step "$GLOSS" status
step "$GLOSS" diff --base HEAD --fail-on none

printf '\n$ gloss export --prov prov.jsonld && jq ...   # two activities\n'
"$GLOSS" export --prov "$TMP/prov.jsonld" >/dev/null
jq -c '.["@graph"][] | select(.["@id"] == "urn:gloss:activity:menu-repo-helper" or .["@id"] == "urn:gloss:activity:ticket-bump-route")' "$TMP/prov.jsonld"
