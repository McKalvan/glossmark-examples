#!/usr/bin/env bash
# Reproduces every finding in FINDINGS.md. Committed workspaces are only read;
# every mutation runs on a copy in a temporary directory.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GLOSS="${GLOSS:-$(cd "$(dirname "$0")/../.." && pwd)/.tools/bin/gloss}"
export GLOSS_ACTOR="${GLOSS_ACTOR:-agent:claude-code}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

section() { printf '\n### %s\n' "$*"; }
copy() { rm -rf "$TMP/$2"; cp -r "$HERE/$1" "$TMP/$2"; cd "$TMP/$2" || exit 1; }
rebuild() { "$GLOSS" build >/dev/null; }
violations() { "$GLOSS" drift --all --fail-on none 2>/dev/null | grep -E "^  $1" | cut -c1-"${2:-220}"; }

section "Committed catalogue: check, drift"
cd "$HERE/catalogue" || exit 1
"$GLOSS" check 2>&1 | grep -c GM503 | sed 's/^/GM503 warnings: /'
"$GLOSS" check 2>&1 | tail -1
"$GLOSS" drift --fail-on none 2>/dev/null

section "Committed catalogue: drift --all (consistent pairs)"
"$GLOSS" drift --all --fail-on none 2>/dev/null | sed -n '/Consistent/,/^$/p' | cut -c1-240

section "check --explain: characters per manifest line"
"$GLOSS" check --explain 2>/dev/null | grep 'allowed =' | awk '{print length($0) "  " $1}'

section "Derived realizes and its via chain (feeds, scanning)"
python3 - .glossmark/graph.jsonl <<'PY'
import json, sys
short = lambda s: s.replace('https://onto.spokewise.example/core/', 'cyc:').replace('https://onto.spokewise.example/impl/', 'spk:').rsplit('/boundaries/spw/', 1)[-1]
for line in open(sys.argv[1]):
    r = json.loads(line)
    if r.get('type') == 'edge' and r['p'] == 'realizes' and r['source'] == 'derived' and r['s'].endswith(('/feeds', '/scanning')):
        print(short(r['s']), short(r['o']), 'via', r['prov'].get('via'))
PY

section "Criticality and its provenance"
python3 - .glossmark/graph.jsonl <<'PY'
import json, sys
for line in open(sys.argv[1]):
    r = json.loads(line)
    if r.get('type') == 'node' and r.get('curie') in ('cyc:HydraulicDiscBrake', 'cyc:DiscBrake', 'cyc:Brake', 'cyc:BrakingComponent', 'cyc:ScanConfirm', 'spk:ShimanoXmlImporter', 'spk:XmlFeedImporter', 'spk:ScanVerifier', 'spk:FulfilmentEngine'):
        print(r['curie'], r.get('criticality'), 'from', r.get('criticality-from'), '| kind:', r.get('kind', '(none)'))
PY

section "impact on a file that links is-a-only concepts"
"$GLOSS" impact services/catalogue/ingest/feeds/shimano_xml.py 2>&1 | grep -E '\(, '

section "view --json: boundary placement and folding"
"$GLOSS" view --json -o "$TMP/views.json" >/dev/null
python3 - "$TMP/views.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for v in d['views']:
    for n in v['nodes']:
        if v['name'] == 'components' and n['id'] in ('cyc:OrderFulfilment', 'spk:FulfilmentEngine', 'spk:PickPlanner', 'cyc:CatalogueIngestion'):
            print('components:', n['id'], '->', n.get('boundary'))
        if v['name'] == 'business' and n['id'] == 'cyc:CatalogueIngestion':
            print('business: cyc:CatalogueIngestion folds', n.get('folded'))
    if v['name'] == 'drivetrain':
        print('drivetrain (curated, lift: range-lcs) edges:', [(e['s'], e['p'], e['o']) for e in v['edges']])
PY

section "F-DEEP-1: a leaf part covers its whole (scanning declares cyc:ScanConfirm, code implements cyc:OrderFulfilment)"
copy catalogue m-partof
sed -i 's/^realizes: \[cyc:OrderFulfilment\]/realizes: [cyc:ScanConfirm]/' services/fulfilment/picking/scanning/.gloss.yaml
sed -i 's/@gloss implements spk:ScanVerifier/@gloss implements cyc:OrderFulfilment/' services/fulfilment/picking/scanning/verifier.py
rebuild; violations 'spw:scanning'
echo "-- control, is-a: declares cyc:Cassette, code implements its parent cyc:DrivetrainComponent"
sed -i 's/^realizes: \[cyc:ScanConfirm\]/realizes: [cyc:Cassette]/' services/fulfilment/picking/scanning/.gloss.yaml
sed -i 's/@gloss implements cyc:OrderFulfilment/@gloss implements cyc:DrivetrainComponent/' services/fulfilment/picking/scanning/verifier.py
rebuild; violations 'spw:scanning'

section "F-DEEP-5: declaring spk:Importer admits its is-a descendants but not spk:CsvRowParser (part-of an is-a descendant)"
copy catalogue m-allowed
sed -i 's/^realizes: \[cyc:CatalogueIngestion\]/realizes: [spk:Importer]/' services/catalogue/ingest/feeds/.gloss.yaml
"$GLOSS" check --explain 2>&1 | grep -E '^spw:feeds|feeds/.*GM503' | cut -c1-400
rebuild; violations 'spw:feeds'

section "F-DEEP-6: one omission under two inherit levels (ingest: inherit only, feeds: no realizes)"
copy catalogue m-inherit
sed -i 's/^realizes: \[inherit, cyc:CatalogueIngestion\]/realizes: inherit/' services/catalogue/ingest/.gloss.yaml
sed -i '/^realizes:/d' services/catalogue/ingest/feeds/.gloss.yaml
rebuild
"$GLOSS" drift --fail-on none 2>/dev/null | grep -E '^  spw:.* but declares ' | awk '{print length($0) " chars: " substr($0, 3, 60) "..."}'

section "F-DEEP-6: one marker on a deep part fans out (picking declares cyc:Picking only)"
copy catalogue m-fanout
sed -i 's/^realizes: \[inherit, cyc:Picking\]/realizes: [cyc:Picking]/' services/fulfilment/picking/.gloss.yaml
rebuild; violations 'spw:picking' 110

section "F-DEEP-8: orphans without the produces markers"
copy catalogue m-orphan
sed -i '/@gloss produces/d' services/catalogue/ingest/feeds/*.py
rebuild; "$GLOSS" drift --fail-on none 2>/dev/null | grep 'orphan concept' | cut -c1-60

section "F-DEEP-9: range-lcs on the feed's produces"
lcs() {
  copy catalogue m-lcs
  sed -i '/@gloss produces/d' services/catalogue/ingest/feeds/csv_feed.py
  sed -i "s/@gloss produces .*/@gloss produces $1/" services/catalogue/ingest/feeds/shimano_xml.py
  rebuild; echo "-- produces {$1}"; violations 'spw:feeds produces' 200
}
lcs "cyc:ElectronicRearDerailleur, cyc:Cassette"
lcs "cyc:RearDerailleur, cyc:FrontDerailleur"
lcs "cyc:ElectronicRearDerailleur, cyc:FrontDerailleur"
lcs "cyc:ElectronicRearDerailleur, cyc:ElectronicFrontDerailleur"
lcs "cyc:ElectronicRearDerailleur, cyc:FrontLight"

section "F-DEEP-3: cycles"
cd "$HERE/cycles" || exit 1
"$GLOSS" check 2>&1 | tail -1
"$GLOSS" drift --fail-on none 2>/dev/null | grep -E '^  spw:' | cut -c1-200
echo "-- control: the same workspace without 'Product is-a Lighting'"
copy cycles m-nocycle
sed -i 's/{ kind: entity, is-a: Lighting, doc/{ kind: entity, doc/' ontology/cyc.gloss.yaml
rebuild; "$GLOSS" drift --fail-on none 2>/dev/null | grep -E '^  spw:listing' | cut -c1-120

section "F-DEEP-4: parent boundary in a sibling directory"
cd "$HERE/sibling-parent" || exit 1
grep '"node":"boundary"' .glossmark/graph.jsonl
"$GLOSS" drift --fail-on none 2>/dev/null | grep 'declares realizes'
