#!/usr/bin/env bash
# gloss publish in shipment-core: what the two namespaces it owns look like to the
# rest of the company. Writes only to a temporary directory; dist/ is never committed.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cd "$HERE/shipment-core"
echo "\$ gloss publish -o \$OUT"
"$GLOSS" publish -o "$OUT" 2>&1 | sed "s|[./]*${OUT#/}|\$OUT|"
echo; echo "\$ find \$OUT -type f | sort"
(cd "$OUT" && find . -type f | sort | sed 's|^\./|$OUT/|')
summary() {
  python3 -I - "$1" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
nodes = doc.get("@graph", [])
print(f"{len(nodes)} concepts")
for n in nodes:
    extra = {k: v for k, v in n.items() if k in ("published-as", "gm:value", "realizes", "publishes")}
    print(f"  {n['@id']:<28} {n.get('gm:kind', ''):<11} {json.dumps(extra, sort_keys=True) if extra else ''}")
PY
}
echo; echo "\$ # frt/ontology.jsonld: the whole core tier"
summary "$OUT/frt/ontology.jsonld"
echo; echo "\$ # shc/ontology.jsonld: only the published implementation concepts"
summary "$OUT/shc/ontology.jsonld"
echo; echo "\$ # shc/graph.jsonl: the boundaries and links that reference them"
python3 -I - "$OUT/shc/graph.jsonl" <<'PY'
import collections, json, sys
recs = [json.loads(l) for l in open(sys.argv[1])]
print(f"{len(recs)} records:", dict(sorted(collections.Counter(r.get("node") or r["type"] for r in recs).items())))
print("shc: concepts:", sorted(r["curie"] for r in recs if r.get("node") == "concept" and r["ns"] == "shc"))
print("boundaries:", sorted(r["curie"] for r in recs if r.get("node") == "boundary"))
edges = collections.Counter(f'{r["p"]} ({r["source"]})' for r in recs if r["type"] == "edge")
print("edges:", ", ".join(f"{k} {v}" for k, v in sorted(edges.items())))
PY
echo; echo "\$ grep -c '^  [A-Z]' \$OUT/shc/shc.gloss.yaml   # the copied ontology file still lists every shc: concept"
grep -c '^  [A-Z]' "$OUT/shc/shc.gloss.yaml"
