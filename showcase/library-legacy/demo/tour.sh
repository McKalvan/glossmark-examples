#!/usr/bin/env bash
# A read-only tour of the commands this example owns: the importers (dry run),
# check, coverage, the status export and doctor. Writes only to a temporary directory.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cd "$HERE"
step() { printf '\n$ gloss %s\n' "$*"; "$GLOSS" "$@"; }
step version
step import --from markdown-glossary --namespace lib --dry-run docs/glossary.md
step import --from enums --namespace lib --values --dry-run config/enums.yaml
step check
step coverage
step export --status -o "$OUT/status.json"
echo; echo "\$ jq -r '.[] | .tier + \" \" + .status' status.json | sort | uniq -c"
jq -r '.[] | .tier + " " + .status' "$OUT/status.json" | sort | uniq -c
cmp -s "$OUT/status.json" docs/vocabulary-status.json && echo "docs/vocabulary-status.json is current" || echo "docs/vocabulary-status.json differs: rerun gloss export --status -o docs/vocabulary-status.json"
step doctor || true
