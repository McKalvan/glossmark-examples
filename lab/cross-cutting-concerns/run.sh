#!/usr/bin/env bash
# Reproduces every claim in FINDINGS.md. Read-only: anything that writes runs
# on a copy in a temporary directory.
set -uo pipefail
GLOSS="${GLOSS:-$(cd "$(dirname "$0")/../.." && pwd)/.tools/bin/gloss}"
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export GLOSS_ACTOR=agent:claude-code
A=variant-a-platform-only
B=variant-b-every-handler
C=variant-c-constraints

say() { printf '\n==== %s\n' "$*"; }
copy() { rm -rf "$T/$2"; cp -r "$HERE/$1" "$T/$2"; }          # copy <variant> <name>
gitcopy() {                                                    # copy into a temp git repo, before-state committed
  copy "$1" "$2"
  (cd "$T/$2" && git init -q && git add -A &&
   git -c user.email=lab@example.invalid -c user.name=lab commit -qm before)
}
crit() {                                                       # effective criticality of every handler artifact
  python3 - "$1" <<'EOF'
import json, sys
for l in open(sys.argv[1] + "/.glossmark/graph.jsonl"):
    r = json.loads(l)
    if r.get("node") == "artifact" and "/handlers/" in r.get("path", ""):
        a = r["anchor"]
        print(f'  {r["path"].split("/")[-1]:12} {a.get("symbol") or a["scope"]:20} {r.get("criticality")}  (from {r.get("criticality-from")})')
EOF
}

say "0. The three variants side by side"
for v in $A $B $C; do
  copy "$v" "s-$v"
  ( cd "$T/s-$v"
    echo "--- $v"
    "$GLOSS" build 2>&1 | sed 's/ in [0-9.]*ms//'
    "$GLOSS" check
    "$GLOSS" drift 2>/dev/null | grep '^Concepts covered'
    "$GLOSS" coverage | head -1
    echo "impact of the auth module:"
    "$GLOSS" impact service/app/platform/auth.py
    echo "handler criticality:"
    crit . )
done

say "1. Deleting @requires_role(\"approver\") from approve_claim (every variant)"
for v in $A $B $C; do
  gitcopy "$v" "r1-$v"
  ( cd "$T/r1-$v"
    python3 - <<'EOF'
p = "service/app/handlers/claims.py"
s = open(p).read()
s = s.replace('@requires_role("approver")\n@rate_limit("claims-write")\ndef approve_claim',
              '@rate_limit("claims-write")\ndef approve_claim', 1)
open(p, "w").write(s)
EOF
    echo "--- $v: $(git diff --numstat -- service | tr '\t' ' ')"
    "$GLOSS" build -q
    "$GLOSS" diff --base HEAD
    "$GLOSS" drift 2>/dev/null | grep '^Concepts covered' )
done
echo "--- contrast ($A): change the def line of approve_claim instead"
gitcopy $A r1b
( cd "$T/r1b"
  sed -i 's/^def approve_claim(claim_id: UUID):/def approve_claim(claim_id: UUID, *, note: str = ""):/' service/app/handlers/claims.py
  "$GLOSS" build -q
  "$GLOSS" diff --base HEAD )

say "2. constrains reaches impact; the custom guards relation does not ($C)"
( cd "$T/s-$C"
  echo "guards edges in the graph: $(grep -c '"p":"guards"' .glossmark/graph.jsonl)"
  echo "impact of claims.py, lines naming constrains or guards:"
  "$GLOSS" impact service/app/handlers/claims.py | grep -E 'constrains|constrained|guards|guarded'
  echo "impact of auth.py, lines naming constrains or guards:"
  "$GLOSS" impact service/app/platform/auth.py | grep -E 'constrains|constrained|guards|guarded'
  echo "context --dir service/app/handlers, lines naming constrains or guards: $("$GLOSS" context --dir service/app/handlers --budget 0 | grep -c -E 'constrains|constrained|guards|guarded')" )

say "3. An internal, high-criticality concern loses its only test ($A)"
copy $A r3
( cd "$T/r3"
  rm service/tests/test_auth.py
  "$GLOSS" build -q
  "$GLOSS" drift 2>/dev/null | grep -E 'is implemented but|^Concepts covered'
  "$GLOSS" coverage | head -1
  "$GLOSS" impact service/app/platform/auth.py )
echo "--- same concept made non-internal: the coverage denominator grows by one"
copy $A r3b
( cd "$T/r3b"
  python3 - <<'EOF'
p = "ontology/xapi.gloss.yaml"
s = open(p).read()
s = s.replace("  FeatureFlags:\n    kind: capability\n    internal: true",
              "  FeatureFlags:\n    kind: capability\n    realizes: exp:ClaimExport")
open(p, "w").write(s)
EOF
  "$GLOSS" build -q; "$GLOSS" coverage | head -1 )

say "4. GM131 and stacked markers ($A copy)"
copy $A r4
probe() {                       # probe <marker>... : three functions, each with the given marker lines
  { printf 'def zero():\n    return 0\n'
    for f in one two three; do printf '\n\n'; for m in "$@"; do printf '# @gloss %s\n' "$m"; done; printf 'def %s():\n    return 1\n' "$f"; done
  } > "$T/r4/service/app/handlers/probe131.py"
  (cd "$T/r4" && "$GLOSS" check)
}
echo "--- one identical marker on three functions";  probe "implements .RequestLogging"
echo "--- the same, with a second identical marker stacked on each"; probe "implements .ClaimQueries" "implements .RequestLogging"
echo "--- one identical two-target marker on three functions"; probe "implements .ClaimQueries, .RequestLogging"
echo "--- $B as committed (.Authentication on 5 consecutive handlers):"
(cd "$HERE/$B" && "$GLOSS" check)

say "5. scope=block above a run of Python functions anchors one function"
copy $A r5
( cd "$T/r5"
  printf 'def one():\n    return 1\n\n\ndef two():\n    return 2\n\n\ndef three():\n    return 3\n' > service/app/handlers/probe_block.py
  sed -i '1i # @gloss implements .RequestLogging scope=block' service/app/handlers/probe_block.py
  python3 - <<'EOF'
p = "service/app/handlers/claims.py"
s = open(p).read()
s = s.replace("# @gloss implements .SubmitClaimHandler\n", "# @gloss implements .RequestLogging scope=block\n# @gloss implements .SubmitClaimHandler\n", 1)
open(p, "w").write(s)
EOF
  "$GLOSS" build -q
  python3 - <<'EOF'
import json
for l in open(".glossmark/graph.jsonl"):
    r = json.loads(l)
    if r.get("type") == "edge" and r["p"] == "implements" and r["prov"].get("scope") == "block":
        print(f'  {r["prov"]["path"]}:{r["prov"]["line"]} block -> {r["s"].split("#")[-1]}')
    if r.get("node") == "artifact" and r["anchor"].get("scope") == "block":
        a = r["anchor"]; print(f'  anchor {r["path"]} {a["symbol"]} lines {a["start"]}-{a["end"]}')
EOF
  sed -n 17,22p service/app/handlers/claims.py )

say "6. value-from symbol on a YAML key ($C)"
copy $C r6
( cd "$T/r6"
  sed -i '/publishes-value .ClaimWriteRateLimit/d' service/config/ratelimit.yaml
  printf 'claims_write_per_minute: 30\n' >> service/config/ratelimit.yaml
  python3 - <<'EOF'
p = "ontology/xapi.gloss.yaml"
s = open(p).read()
s = s.replace('    value: "30"\n', '    value: "30"\n    value-from: { path: service/config/ratelimit.yaml, symbol: per_minute }\n')
open(p, "w").write(s)
EOF
  echo "--- nested key per_minute:"; "$GLOSS" check
  sed -i 's/symbol: per_minute }/symbol: claims_write_per_minute }/' ontology/xapi.gloss.yaml
  echo "--- top-level key claims_write_per_minute:"; "$GLOSS" check
  sed -i 's/symbol: claims_write_per_minute }/symbol: policies.claims-write.per_minute }/' ontology/xapi.gloss.yaml
  echo "--- dotted path policies.claims-write.per_minute:"; "$GLOSS" check
  sed -i 's/symbol: policies.claims-write.per_minute }/line: 5 }/' ontology/xapi.gloss.yaml
  echo "--- line: 5:"; "$GLOSS" check )

say "7. Flipping the feature flag ($C)"
gitcopy $C r7
( cd "$T/r7"
  sed -i 's/^    enabled: false/    enabled: true/' service/config/flags.yaml
  "$GLOSS" build -q
  "$GLOSS" drift; echo "drift exit $?"
  "$GLOSS" diff --base HEAD; echo "diff exit $?" )

say "8. criticality suggest on internal engineering constraints ($C without the reviewed levels)"
copy $C r8
( cd "$T/r8"
  sed -i '/criticality: medium        # reviewed/d; /criticality: low           # reviewed/d' ontology/xapi.gloss.yaml
  "$GLOSS" criticality suggest | grep '→' )

say "9. impact says core concepts have no tests although drift does not ($A)"
( cd "$T/s-$A"
  "$GLOSS" impact service/app/handlers/claims.py | grep -B2 'no tests'
  "$GLOSS" drift 2>/dev/null | grep -c 'ClaimApproval is implemented but nothing tests' )

say "10. An undeclared custom relation: GM200 once per target ($C)"
copy $C r10
( cd "$T/r10"
  python3 - <<'EOF'
p = "ontology/xapi.gloss.yaml"
s = open(p).read().replace("relations:\n  guards: {}\n", "")
open(p, "w").write(s)
EOF
  "$GLOSS" check 2>&1 | cut -c1-110 )

say "11. impact --base reports an empty base ($B, decorator removed as in 1)"
( cd "$T/r1-$B"
  echo "impact: $("$GLOSS" impact --base HEAD | tail -1)"
  echo "diff:   $("$GLOSS" diff --base HEAD | grep '^Concepts covered')"
  "$GLOSS" impact --base HEAD --format json | python3 -c 'import json,sys; d=json.load(sys.stdin)["impact"]; print("impact.before:", {k: d["before"][k] for k in ("concepts_in_scope","concepts_covered","covered_files")})' )

say "12. Probe: one scope=file auth marker per handler file instead of one per handler ($A + 2 markers)"
copy $A r12
( cd "$T/r12"
  for f in claims exports; do sed -i '1i # @gloss implements .Authentication scope=file' "service/app/handlers/$f.py"; done
  "$GLOSS" check
  "$GLOSS" build 2>&1 | sed 's/ in [0-9.]*ms//'
  "$GLOSS" impact service/app/platform/auth.py | grep 'also linked'
  crit . )
exit 0
