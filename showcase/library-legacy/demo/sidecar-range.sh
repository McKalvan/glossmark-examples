#!/usr/bin/env bash
# What a scope=range marker in a JSON sidecar anchors to in v0.1.0.
# config/loan-rules.json.gloss holds six markers, each with a JSON Pointer in note=.
# The workspace is copied to a temporary directory. Nothing here is modified.
#   1. the graph: how many artifacts the six markers produce, and their line range
#   2. change the DVD loan period in the JSON: is any link stale?
#   3. reword the comment in the sidecar: is any link stale?
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
export GLOSS_ACTOR=agent:claude-code
echo "== 1. artifacts for config/loan-rules.json in the graph"
grep '"node":"artifact"' .glossmark/graph.jsonl | grep '"path":"config/loan-rules.json"' \
  | sed -E 's/.*"id":"([^"]*)".*"anchor":\{"scope":"([a-z]*)","start":([0-9]*),"end":([0-9]*).*"file":"([^"]*)".*/\1  scope=\2 lines \3-\4 (from \5)/'
printf 'config/loan-rules.json has %s lines; the sidecar has %s\n' "$(wc -l < config/loan-rules.json)" "$(wc -l < config/loan-rules.json.gloss)"

echo; echo "== 2. DVD loan period 7 -> 14 days in config/loan-rules.json"
sed -i 's/"DVD": { "loanDays": 7/"DVD": { "loanDays": 14/' config/loan-rules.json
"$GLOSS" build -q
printf 'stale links: %s\n' "$("$GLOSS" drift 2>/dev/null | grep -c 'is stale')"

echo; echo "== 3. reword the comment line of config/loan-rules.json.gloss"
sed -i '1s/.*/# Sidecar for loan-rules.json; note= holds a JSON Pointer./' config/loan-rules.json.gloss
"$GLOSS" build -q
"$GLOSS" drift 2>/dev/null | grep 'is stale' | sed -E 's/ is stale, the anchored signature changed since it was accepted; re-confirm with gloss accept m-[0-9a-f]+//'
