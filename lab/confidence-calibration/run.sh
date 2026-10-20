#!/usr/bin/env bash
# Reproduces the confidence-calibration experiment: regenerates every suggest batch
# and gate classification in temp copies, diffs them against data/, prints the
# F-CAL-2 and F-CAL-6 repros, and recomputes the tables from data/labels.csv.
# Never writes inside the repository.
set -uo pipefail
GLOSS="${GLOSS:-/home/ckessler/dev/glossmark-examples/.tools/bin/gloss}"
export GLOSS_ACTOR=agent:claude-code
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
status=0

strip_markers() { # $1 = workspace copy: delete every @gloss / @gloss? line outside ontology and manifests
  (cd "$1" && rm -rf .glossmark && grep -rl "@gloss" --exclude-dir=ontology --exclude-dir=demo \
     --exclude='.gloss.yaml' --exclude='expected-*' --exclude=README.md . 2>/dev/null |
   while read -r f; do sed -i -E '/^\s*(\/\/|#|--|<!--|\/\*|\*)\s*@gloss\??\s/d' "$f"; done)
}
same_json() { # $1 label, $2 actual, $3 expected
  if python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1])) != json.load(open(sys.argv[2])))' "$2" "$3"; then
    echo "  $1: identical to data/$(basename "$3")"
  else
    echo "  $1: DIFFERS from data/$(basename "$3")"; status=1
  fi
}
gate_json() { # $1 workspace copy, $2 output: diff --base HEAD after suggest --write
  (cd "$1" && git init -q . && "$GLOSS" build >/dev/null 2>&1 && git add -A &&
   git -c user.email=lab@example.invalid -c user.name=lab commit -qm before &&
   "$GLOSS" suggest --write 2>/dev/null && "$GLOSS" build >/dev/null 2>&1 &&
   "$GLOSS" diff --base HEAD --format json > "$2" 2>/dev/null; true)
}
gate_counts() { python3 -c 'import json,sys,collections; d=json.load(open(sys.argv[1])); print("  gates:", dict(collections.Counter(c["gate"] for c in d["changes"])), "over", len(d["changes"]), "links")' "$1"; }

echo "== 1. clinic-booking batch (showcase/clinic-booking, markers stripped)"
cp -r "$REPO/showcase/clinic-booking" "$TMP/clinic"; strip_markers "$TMP/clinic"
(cd "$TMP/clinic" && "$GLOSS" suggest --format json > "$TMP/clinic.json")
same_json "committed manifests" "$TMP/clinic.json" "$HERE/data/clinic-booking-suggest.json"
cp -r "$TMP/clinic" "$TMP/clinic-na"; sed -i '/^allowed:/d' "$TMP/clinic-na/services/reminders/.gloss.yaml"
(cd "$TMP/clinic-na" && "$GLOSS" suggest --format json > "$TMP/clinic-na.json")
same_json "reminders allowed: removed (the coordinator's 126)" "$TMP/clinic-na.json" "$HERE/data/clinic-booking-suggest-noallowed.json"

echo "== 2. meterworks batch"
cp -r "$HERE/meterworks" "$TMP/mw"; rm -rf "$TMP/mw/.glossmark"
(cd "$TMP/mw" && "$GLOSS" suggest --format json > "$TMP/mw.json")
same_json "committed manifests" "$TMP/mw.json" "$HERE/data/meterworks-suggest.json"
cp -r "$TMP/mw" "$TMP/mw-na"; sed -i '/^allowed:/d' "$TMP/mw-na/services/ingest/.gloss.yaml"
(cd "$TMP/mw-na" && "$GLOSS" suggest --format json > "$TMP/mw-na.json")
same_json "ingest allowed: removed" "$TMP/mw-na.json" "$HERE/data/meterworks-suggest-noallowed.json"

echo "== 3. F-CAL-2: suggest --write, then check (lint findings suggest itself introduced)"
for v in clinic clinic-na mw mw-na; do
  cp -r "$TMP/$v" "$TMP/w-$v"
  (cd "$TMP/w-$v" && "$GLOSS" suggest --write 2>&1 | sed 's/^/  /'
   "$GLOSS" check 2>&1 | grep -o 'GM[0-9]*' | sort | uniq -c | sed "s/^/  $v /"
   "$GLOSS" check 2>&1 | tail -1 | sed 's/^/  /')
done
echo "  allowed: [derived, ...] is read literally: proposals dropped by the written list"
python3 - "$TMP" <<'PY'
import json, sys
t = sys.argv[1]
k = lambda x: (x["path"], x["line"], x["symbol"], x["relation"], x["target"])
for a, b in (("clinic", "clinic-na"), ("mw", "mw-na")):
    A, B = json.load(open(f"{t}/{a}.json")), json.load(open(f"{t}/{b}.json"))
    ka = set(map(k, A))
    print(f"  {a}: {len(B)} -> {len(A)}; dropped {sum(k(x) not in ka for x in B)}, e.g.",
          [f"{x['symbol']} {x['relation']} {x['target']} {x['conf']}" for x in B if k(x) not in ka][:3])
PY

echo "== 4. gate classes after suggest --write (gloss diff --base HEAD --format json)"
for v in clinic clinic-na mw mw-na; do
  cp -r "$TMP/$v" "$TMP/g-$v"; gate_json "$TMP/g-$v" "$TMP/g-$v.json"; echo "  $v"; gate_counts "$TMP/g-$v.json"
done
python3 - "$TMP" "$HERE/data/labels.csv" <<'PY'
import csv, json, sys
t, labels = sys.argv[1], list(csv.DictReader(open(sys.argv[2])))
def norm(x, ns): return ns + ":" + x[1:] if x.startswith(".") else x
for v, cb, ns, col in (("clinic-na", "clinic-booking", "lark", "gate_noallowed"), ("clinic", "clinic-booking", "lark", "gate_committed"),
                       ("mw-na", "meterworks", "mw", "gate_noallowed"), ("mw", "meterworks", "mw", "gate_committed")):
    g = {(c["path"], c["symbol"], c["relation"], c["object"]): c["gate"] for c in json.load(open(f"{t}/g-{v}.json"))["changes"]}
    bad = [r["symbol"] for r in labels if r["codebase"] == cb and r[col] and g.get((r["path"], r["symbol"], r["relation"], norm(r["target"], ns))) != r[col]]
    print(f"  {v}: gate column {col} in labels.csv", "matches" if not bad else f"DIFFERS for {bad}")
    if bad: sys.exit(1)
PY
[ $? -eq 0 ] || status=1

echo "== 5. F-CAL-6: two identical proposals on one Rust type (struct + impl block)"
cp -r "$TMP/mw-na" "$TMP/dup"
(cd "$TMP/dup" && "$GLOSS" suggest --write 2>/dev/null && "$GLOSS" build >/dev/null 2>&1
 id=$("$GLOSS" status 2>&1 | awk '/filter.rs/ {print $1; exit}')
 echo "  marker id: $id"; "$GLOSS" accept "$id" 2>&1 | sed 's/^/  /'
 grep -n '@gloss' services/ingest/src/filter.rs | sed 's/^/  filter.rs:/'
 "$GLOSS" build >/dev/null 2>&1; "$GLOSS" status 2>&1 | grep filter.rs | sed 's/^/  still proposed: /'
 "$GLOSS" accept "$id" 2>&1 | sed 's/^/  /')

echo "== 6. tables from data/labels.csv"
python3 "$HERE/calibrate.py"
exit $status
