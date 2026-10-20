#!/usr/bin/env bash
# Reproduces every observation in FINDINGS.md. Read-only on this directory:
# anything that writes runs on a copy in a temporary directory.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
export GLOSS_ACTOR=agent:claude-code
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
copy() { local d; d=$(mktemp -d -p "$TMP"); cp -r "$HERE/$1/." "$d/"; echo "$d"; }
gitrepo() { (cd "$1" && git init -q && git add -A && git -c user.name=lab -c user.email=lab@example.invalid commit -qm base); }
overlay() { find "$1" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +; cp -r "$HERE/$2/." "$1/"; }
section() { printf '\n===== %s\n' "$*"; }

for ws in before during after during-split/invoicing-service during-split/hirehq; do
  section "$ws: check and drift --all"
  (cd "$HERE/$ws" && "$GLOSS" check; "$GLOSS" drift --all --fail-on none)
done

section "F-SPLIT-2: landscape over the sibling repos (no finding for two repos realizing hire:Invoicing)"
(cd "$HERE/during-split" && "$GLOSS" landscape --repo hirehq --repo invoicing-service --all --fail-on none)

section "F-SPLIT-1: a rebuild in another checkout path rewrites graph.jsonl (absolute import paths)"
d=$(copy during-split); (cd "$d/invoicing-service" && "$GLOSS" build -q)
echo "graph.jsonl lines naming the committed checkout path: $(grep -c "$HERE" "$HERE/during-split/invoicing-service/.glossmark/graph.jsonl")"
echo "lines that differ after the rebuild in $d: $(diff "$HERE/during-split/invoicing-service/.glossmark/graph.jsonl" "$d/invoicing-service/.glossmark/graph.jsonl" | grep -c '^>')"
grep -o '"curie":"hire:Invoice","[^}]*' "$HERE/during-split/invoicing-service/.glossmark/graph.jsonl" | grep -o '"file":"[^"]*"'

section "F-SPLIT-4: rewriting a core concept's definition, with no version bump, passes --fail-on HARD"
d=$(copy before); gitrepo "$d"
sed -i 's|doc: "A returned hire is priced by the day and invoiced to the customer."|doc: "A hire is invoiced to the customer weekly in advance, whether or not it has been returned."|' "$d/ontology/hire.gloss.yaml"
(cd "$d" && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on HARD; echo "exit=$?")

section "F-SPLIT-5: diff before -> during"
d=$(copy before); gitrepo "$d"; overlay "$d" during
(cd "$d" && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on none)

section "F-SPLIT-5: diff during -> after"
d=$(copy during); gitrepo "$d"; overlay "$d" after
(cd "$d" && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on none)

section "F-SPLIT-6: retirement keys on a manifest (GM110, the manifest is dropped)"
d=$(copy during)
printf 'deprecated: true\nreplaced-by: bw:invoicing-service\nretire-by: 2026-12-31\n' >> "$d/monolith/hirehq/invoicing/.gloss.yaml"
(cd "$d" && "$GLOSS" check; "$GLOSS" build -q; "$GLOSS" drift 2>&1 | grep -E '^gloss drift|Violations:')

section "F-SPLIT-7: the migration view carries no deprecated flag and no replaced-by edge"
d=$(copy during)
(cd "$d" && "$GLOSS" view --json -o "$d/v.json" >/dev/null)
python3 - "$d/v.json" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
v = [x for x in d["views"] if x["name"] == "invoicing-migration"][0]
print("view nodes with a deprecated key:", sum(1 for n in v["nodes"] if "deprecated" in n))
print("view edge predicates:", sorted({e["p"] for e in v["edges"]}))
print("concept panel keys for hq:InvoiceGenerator:", sorted(d["concepts"]["hq:InvoiceGenerator"]))
EOF
grep -c '"p":"replaced-by"' "$HERE/during/.glossmark/graph.jsonl"

section "F-SPLIT-9: deprecation alone is classified PATCH"
d=$(copy before); gitrepo "$d"
sed -i 's|    realizes: hire:Invoicing|    realizes: hire:Invoicing\n    deprecated: true\n    replaced-by: hq:BookingView|' "$d/ontology/hq.gloss.yaml"
(cd "$d" && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on none | grep -E 'deprecated|Version')

section "F-SPLIT-8: cross-repo replaced-by without importing the replacement's namespace"
d=$(copy during-split)
sed -i '/^imports:/,/^prefixes:/{/^imports:/d;/inv:/d}' "$d/hirehq/glossmark.yaml"; rm -f "$d/hirehq/glossmark.lock"
(cd "$d/hirehq" && "$GLOSS" check)

section "F-SPLIT-3: an imported namespace without tier: is typed core, so GM230 never fires"
d=$(copy during-split)
printf '# @gloss implements inv:InvoiceRun\ndef probe():\n    pass\n' > "$d/hirehq/monolith/hirehq/invoicing/probe.py"
echo "allowed: [derived, inv:InvoiceRun]" >> "$d/hirehq/monolith/hirehq/invoicing/.gloss.yaml"
echo "with tier: implementation on the import:"; (cd "$d/hirehq" && "$GLOSS" check)
sed -i 's/ tier: implementation, version: "\^0.1"/ version: "^0.1"/' "$d/hirehq/glossmark.yaml"
echo "without it:"; (cd "$d/hirehq" && "$GLOSS" lock >/dev/null && "$GLOSS" check && "$GLOSS" build -q && grep -o '"curie":"inv:InvoiceRun"[^}]*"tier":"[a-z]*"' .glossmark/graph.jsonl)

section "F-SPLIT-10: waivers cannot carry a retirement date (no finding to waive; expired and unknown waivers are silent)"
d=$(copy during)
cat >> "$d/glossmark.yaml" <<'EOF'
policy:
  waivers:
    - { finding: "hq:InvoiceGenerator", owner: invoicing-eng, expires: 2026-12-31, reason: "retire after cutover" }
    - { finding: "hq:InvoicingRouter", owner: invoicing-eng, expires: 2026-01-31, reason: "past its date" }
    - { finding: "bogus:Nothing", owner: nobody, expires: 2020-01-01 }
EOF
(cd "$d" && "$GLOSS" check; "$GLOSS" drift --fail-on none 2>&1 | grep -ciE 'waiv' || true)

section "F-SPLIT-11: landscape context-map header says publishes -> subscribes; arrows point subscriber -> publisher"
d=$(mktemp -d -p "$TMP"); cp -r "$ROOT/../GlossMark/examples/payments/." "$d/" 2>/dev/null && \
  (cd "$d/payments-api" && "$GLOSS" build -q) && (cd "$d/settlement-worker" && "$GLOSS" build -q) && \
  (cd "$d" && "$GLOSS" landscape --repo payments-api --repo settlement-worker --fail-on none | sed -n 3,4p) || \
  echo "(GlossMark checkout not found next to this repo; the hirehq landscape above shows the same header)"

section "F-SPLIT-11: the service joins bw:tool-hire with part-of; the system then depends on its own container"
d=$(copy during-split); echo "part-of: bw:tool-hire" >> "$d/invoicing-service/.gloss.yaml"
(cd "$d/invoicing-service" && "$GLOSS" check && "$GLOSS" build -q)
(cd "$d" && "$GLOSS" landscape --repo hirehq --repo invoicing-service --all --fail-on none | grep 'tool-hire')

section "F-SPLIT-12: diff reports the base's file coverage over the head's file count"
d=$(copy before); gitrepo "$d"
for i in 1 2 3 4 5; do echo "x = $i" > "$d/monolith/hirehq/extra$i.py"; done
(cd "$d" && "$GLOSS" build -q && git stash -q -u && "$GLOSS" drift --fail-on none | grep -o 'Files [^ ]* [^ ]*' && git stash pop -q >/dev/null && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on none | grep -o 'Files [^ ]* → [^ ]*')

section "Worked: a new link to a deprecated concept is HARD"
d=$(copy during); gitrepo "$d"
printf '\n\n# @gloss? implements .InvoiceGenerator conf=0.9\ndef generate_credit_note(invoice, days):\n    return None\n' >> "$d/monolith/hirehq/invoicing/generator.py"
(cd "$d" && "$GLOSS" build -q && "$GLOSS" diff --base HEAD --fail-on none | sed -n 2p)

section "Worked: impact on the legacy file names both realizing boundaries and the replacement"
(cd "$HERE/during" && "$GLOSS" impact monolith/hirehq/invoicing/generator.py)

section "F-SPLIT-13: the briefing for the retiring module hides the deprecated concept but never says it is retiring"
(cd "$HERE/during" && "$GLOSS" context --dir monolith/hirehq/invoicing | sed -n '3,$p')
exit 0
