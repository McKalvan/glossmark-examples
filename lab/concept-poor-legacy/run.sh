#!/usr/bin/env bash
# Reproduces every number and probe in FINDINGS.md. Writes only to a temp directory.
set -uo pipefail
GLOSS="${GLOSS:-/home/ckessler/dev/glossmark-examples/.tools/bin/gloss}"
export GLOSS_ACTOR=agent:claude-code
HERE="$(cd "$(dirname "$0")" && pwd)"
WS="$HERE/opstool"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

section() { printf '\n== %s\n' "$*"; }

# A copy of opstool as it was before adoption: no markers, empty ops tier, init's bare manifests.
pristine() {
  local d="$TMP/$1"
  rm -rf "$d"; cp -r "$WS" "$d"; rm -rf "$d/.glossmark"
  grep -rl '@gloss' "$d" --exclude='*.gloss.yaml' --exclude='.gloss.yaml' | xargs sed -i '/@gloss/d'
  printf 'namespace: ops\nversion: 0.1.0\nconcepts: {}\n' > "$d/ontology/ops.gloss.yaml"
  find "$d" -name .gloss.yaml -exec sed -i '/^realizes:\|^holds:\|^presents:\|^allowed:/d' {} +
  echo "$d"
}

section "A. the committed adoption (opstool/): check, drift, coverage"
(cd "$WS" && "$GLOSS" check && "$GLOSS" drift --fail-on none 2>&1 | tail -1 && "$GLOSS" coverage | head -2)

section "F-POOR-1/2: suggest precision and recall per core-tier variant (truth.tsv, score.py)"
for v in naive domain aliases; do
  d="$(pristine "v-$v")"; cp "$HERE/variants/$v.gloss.yaml" "$d/ontology/wh.gloss.yaml"
  (cd "$d" && "$GLOSS" suggest --format json > "$TMP/$v.json")
  python3 "$HERE/score.py" "$HERE/truth.tsv" "$HERE/variants/$v.gloss.yaml" "$TMP/$v.json" "$v"
done
d="$(pristine adopted-tiers)"; cp "$WS/ontology/ops.gloss.yaml" "$d/ontology/"
(cd "$d" && "$GLOSS" suggest --format json > "$TMP/adopted.json")
python3 "$HERE/score.py" "$HERE/truth.tsv" "$WS/ontology/wh.gloss.yaml" "$TMP/adopted.json" "aliases + ops tier" "$WS/ontology/ops.gloss.yaml" | head -2

section "F-POOR-2: raising --min-score on the aliases variant"
for m in 60 70 80 90; do
  (cd "$TMP/v-aliases" && "$GLOSS" suggest --format json --min-score "$m" > "$TMP/m$m.json")
  python3 "$HERE/score.py" "$HERE/truth.tsv" "$HERE/variants/aliases.gloss.yaml" "$TMP/m$m.json" "min-score $m" | head -1
done

section "F-POOR-2: generic words and fragments (domain variant)"
cat > "$TMP/v-domain/utils/probe.py" <<'PY'
def a(n):
    return n


def ent(n):
    return n


def plen(n):
    return n


def nish(n):
    return n


def process(n):
    return n


def processor(n):
    return n


def handler(n):
    return n
PY
(cd "$TMP/v-domain" && "$GLOSS" suggest --format json | jq -r '.[] | select(.path=="utils/probe.py") | "  \(.symbol) -> \(.target) conf=\(.conf) [\(.matched)]"')
rm "$TMP/v-domain/utils/probe.py"

section "F-POOR-1: docstrings and comments are not read (aliases variant: Replenishment has alias \"top up\")"
cat >> "$TMP/v-aliases/utils/common.py" <<'PY'


def top_up(n):
    return n


# Top up the pick faces (replenishment).
def zz1(n):
    return n


def zz2(n):
    """Replenishment: top up the pick faces."""
    return n
PY
(cd "$TMP/v-aliases" && "$GLOSS" suggest --format json | jq -r '.[] | select(.path=="utils/common.py") | "  \(.symbol) -> \(.target) [\(.matched)]"'; echo "  (zz1 and zz2 absent)")

section "F-POOR-1: evidence suggest does not read (evidence.py)"
python3 "$HERE/evidence.py" "$HERE/truth.tsv" "$WS/ontology/wh.gloss.yaml" "$WS" | grep -v '^            '

section "F-POOR-1: tests that call linked code get no verifies proposal"
d="$TMP/no-tests"; cp -r "$WS" "$d"; sed -i '/@gloss/d' "$d"/tests/*.py
(cd "$d" && "$GLOSS" build -q && echo "  proposals on tests/: $("$GLOSS" suggest --format json | jq '[.[]? | select(.path|startswith("tests/"))] | length')")

section "F-POOR-3: methods are never proposed, even on an exact alias"
d="$(pristine nested)"; cp "$HERE/variants/domain.gloss.yaml" "$d/ontology/wh.gloss.yaml"
sed -i 's/^  WavePlanning:/  WavePlanning:\n    aliases: ["run batch", "do it", "check", "grade"]/' "$d/ontology/wh.gloss.yaml"
(cd "$d" && "$GLOSS" suggest --format json | jq -r '.[] | select(.target=="wh:WavePlanning") | "  \(.path):\(.line) \(.symbol) [\(.matched)]"')
echo "  (no core/Manager.py run_batch or doIt, no Processor.py grade, no StringUtils.java check)"

section "F-POOR-4: two methods named process in one file become one artifact"
d="$TMP/collide"; cp -r "$TMP/v-domain" "$d"
cat > "$d/core/handlers.py" <<'PY'
class InboundHandler:
    # @gloss? implements wh:Replenishment conf=0.9
    def process(self, data):
        return data


class OutboundHandler:
    # @gloss? implements wh:WavePlanning conf=0.9
    def process(self, data):
        return data
PY
(cd "$d" && "$GLOSS" build -q && grep -c '"node":"artifact","id":"urn:gloss:artifact:core/handlers.py' .glossmark/graph.jsonl | sed 's/^/  artifact nodes for core\/handlers.py: /' \
  && grep '"p":"implements"' .glossmark/graph.jsonl | jq -r 'select(.prov.path=="core/handlers.py") | "  \(.s) implements \(.o | sub(".*/"; ""))"')
cat > "$d/core/k.ts" <<'TS'
export class Inbound {
  // @gloss? implements wh:Replenishment conf=0.9
  process(): void {}
}

export class Outbound {
  // @gloss? implements wh:WavePlanning conf=0.9
  process(): void {}
}
TS
mkdir -p "$d/gosvc"; cat > "$d/gosvc/h.go" <<'GO'
package gosvc

type Inbound struct{}

type Outbound struct{}

// @gloss? implements wh:Replenishment conf=0.9
func (i *Inbound) Process() error { return nil }

// @gloss? implements wh:WavePlanning conf=0.9
func (o *Outbound) Process() error { return nil }
GO
(cd "$d" && "$GLOSS" build -q && grep '"node":"artifact"' .glossmark/graph.jsonl | jq -r 'select(.path=="core/k.ts" or .path=="gosvc/h.go") | "  artifact \(.id | sub("urn:gloss:artifact:"; ""))"')

section "F-POOR-5: a rejected proposal still lifts, and suggest proposes it again"
d="$TMP/reject"; cp -r "$WS" "$d"
(cd "$d" && "$GLOSS" drift > /dev/null 2>&1; echo "  drift exit before suggest --write: $?"
  "$GLOSS" suggest --write && "$GLOSS" build -q
  "$GLOSS" drift > /dev/null 2>&1; echo "  drift exit after suggest --write: $?"
  id=$(jq -r 'select(.path=="app.py" and .status=="proposed" and .targets[0]=="wh:AdjustmentApproval") | .marker_id' .glossmark/ledger.jsonl)
  "$GLOSS" reject --reason "the Flask app object, not the approval rule" "$id" && "$GLOSS" build -q
  "$GLOSS" status 2>&1 | sed -n '/^rejected/,$p'
  "$GLOSS" check 2>&1 | grep 'app.py'
  "$GLOSS" drift 2>&1 | grep 'AdjustmentApproval' | cut -c1-90
  id=$(jq -r 'select(.path=="web/functions.php" and .status=="proposed") | .marker_id' .glossmark/ledger.jsonl)
  "$GLOSS" reject --remove --reason "h() is htmlspecialchars" "$id" && "$GLOSS" build -q
  jq -r "select(.marker_id==\"$id\") | \"  ledger status after reject --remove and build: \(.status)\"" .glossmark/ledger.jsonl
  "$GLOSS" suggest --format json | jq -r '.[] | "  proposed again: \(.path) \(.symbol) -> \(.target)"')

section "F-POOR-6: a table that stores a measure"
d="$TMP/measure"; cp -r "$WS" "$d"
(cd "$d" && sed -i '/^allowed:/d' sql/.gloss.yaml && "$GLOSS" check 2>&1 | grep GM503 | cut -c1-110
  sed -i 's/^holds: \[\(.*\)\]/holds: [\1, wh:CountVariance]/' sql/.gloss.yaml && "$GLOSS" build -q && "$GLOSS" drift 2>&1 | grep 'holds wh:CountVariance' | cut -c1-110)

section "F-POOR-7: an empty or thin ontology"
d="$(pristine empty)"; printf 'namespace: wh\nversion: 0.1.0\nconcepts: {}\n' > "$d/ontology/wh.gloss.yaml"
(cd "$d" && echo "  json: $("$GLOSS" suggest --format json)" && echo "  text: '$("$GLOSS" suggest --format text)'" && "$GLOSS" suggest 2>&1 | sed 's/^/  patch: /')
d="$TMP/init"; cp -r "$HERE/opstool" "$d"; rm -rf "$d/.glossmark" "$d/glossmark.yaml" "$d/ontology"; find "$d" -name .gloss.yaml -delete
grep -rl '@gloss' "$d" | xargs sed -i '/@gloss/d'
(cd "$d" && "$GLOSS" init --dry-run | grep -E 'repository|gloss.yaml')

section "Adoption styles: B (internal tier for the glue) and C (unmarked)"
d="$TMP/style-b"; cp -r "$WS" "$d"
cat >> "$d/ontology/ops.gloss.yaml" <<'YAML'
  DbAccess: { kind: process, internal: true, doc: "Raw SQL over one shared connection." }
  OpsManager: { kind: process, internal: true, doc: "The Manager god class." }
  NightlyJob: { kind: process, internal: true, doc: "Cron at 02:30." }
  Alerting: { kind: process, internal: true, doc: "Config loading and supervisor e-mail." }
YAML
sed -i 's/^def get_stuff/# @gloss implements .DbAccess\ndef get_stuff/' "$d/utils/db.py"
sed -i 's/^function q(/\/\/ @gloss implements .DbAccess\nfunction q(/' "$d/web/functions.php"
sed -i 's/^class Manager:/# @gloss implements .OpsManager\nclass Manager:/' "$d/core/Manager.py"
sed -i 's/^def send_mail/# @gloss implements .Alerting\ndef send_mail/' "$d/utils/misc.py"
sed -i 's/^set -euo pipefail/# @gloss implements .NightlyJob\nset -euo pipefail/' "$d/jobs/nightly.sh"
(cd "$d" && "$GLOSS" build -q && echo "  B: $("$GLOSS" drift --fail-on none 2>/dev/null | tail -1)")
d="$TMP/style-c"; cp -r "$WS" "$d"; rm -rf "$d/.glossmark"
grep -rl '@gloss' "$d" --exclude='*.gloss.yaml' --exclude='.gloss.yaml' | xargs sed -i '/@gloss/d'
(cd "$d" && "$GLOSS" build -q && echo "  C: $("$GLOSS" drift --fail-on none 2>/dev/null | tail -1)"
  find . -name .gloss.yaml -exec sed -i '/^realizes:\|^holds:\|^presents:/d' {} + && "$GLOSS" build -q \
  && echo "  C without manifest intents: $("$GLOSS" drift --fail-on none 2>/dev/null | tail -1)")
exit 0
