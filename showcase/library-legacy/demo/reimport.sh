#!/usr/bin/env bash
# The vocabulary importers are re-runnable. This copies the workspace to a
# temporary directory and shows what a re-run changes:
#   1. both importers on the committed sources (expected: no change)
#   2. the glossary edited by the Circulation department (a new definition,
#      a new alias, a new term), then the glossary importer again
# Nothing in this directory is modified.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
export GLOSS_ACTOR=agent:claude-code
cp ontology/lib.gloss.yaml "$TMP/before.yaml"
run() { printf '\n$ gloss %s\n' "$*"; "$GLOSS" "$@"; }

echo "== 1. re-run both importers on the committed sources"
run import --from markdown-glossary --namespace lib docs/glossary.md
run import --from enums --namespace lib --values config/enums.yaml
echo; echo "\$ diff ontology/lib.gloss.yaml (before → after)"
diff "$TMP/before.yaml" ontology/lib.gloss.yaml || true

echo; echo "== 2. the glossary changes: Renewal gets a limit, Hold an alias, a new term"
cp "$TMP/before.yaml" ontology/lib.gloss.yaml
sed -i 's/^\*\*Def.\*\* Extending a loan by one more loan period without bringing the item in.$/**Def.** Extending a loan by one more loan period without bringing the item in; at most twice./' docs/glossary.md
sed -i 's/^\*\*Aliases:\*\* reserve, request$/**Aliases:** reserve, request, hold request/' docs/glossary.md
cat >> docs/glossary.md <<'MD'

## Hold Shelf

**Def.** The shelf behind the desk where trapped holds wait for pickup.
**Status:** implemented
MD
run import --from markdown-glossary --namespace lib docs/glossary.md
echo; echo "\$ diff ontology/lib.gloss.yaml (before → after)"
diff "$TMP/before.yaml" ontology/lib.gloss.yaml || true
echo; echo "\$ grep -c 'import guessed' ontology/lib.gloss.yaml   # the reviewed kinds survived"
grep -c 'import guessed' ontology/lib.gloss.yaml
