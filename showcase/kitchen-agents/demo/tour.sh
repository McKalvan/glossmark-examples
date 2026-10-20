#!/usr/bin/env bash
# A read-only tour of the commands this example owns: the hook files, the agent
# briefing with and without an agent actor, the AGENTS.md vocabulary, impact,
# status and the PROV-O export. Writes only to a temporary directory.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
cd "$HERE"
unset GLOSS_ACTOR
step() { printf '\n$ gloss %s\n' "$*"; "$GLOSS" "$@"; }

printf '\n$ jq . .claude/settings.json .mcp.json   # written by gloss init and gloss hook install\n'
jq -c '.hooks.SessionStart[0].hooks[0]' .claude/settings.json
jq -c '.mcpServers.glossmark' .mcp.json

printf '\n$ gloss context --dir kds   # no agent actor: every remit is listed\n'
"$GLOSS" context --dir kds | grep -E '^(Boundary|Allowed targets|Agent remits|Your remit)'
printf '\n$ GLOSS_ACTOR=agent:allergen-auditor gloss context --dir kds   # only that agent'"'"'s remit\n'
GLOSS_ACTOR=agent:allergen-auditor "$GLOSS" context --dir kds | grep -E '^(Boundary|Allowed targets|Agent remits|Your remit)'

printf '\n$ gloss agents --dir kds   # the vocabulary table, scoped to the display\n'
"$GLOSS" agents --dir kds | sed -n '/^### Concepts/,$p'

step impact api/ordering/services/allergen_guard.py kds/src/views/AllergenBanner.ts
step status
step coverage
printf '\n$ gloss export --prov prov.jsonld   # one activity per marker\n'
"$GLOSS" export --prov "$OUT/prov.jsonld" >/dev/null
jq -r '.["@graph"][] | [.["prov:wasAssociatedWith"], .["gm:status"]] | @tsv' "$OUT/prov.jsonld" | sort | uniq -c
step doctor || true
