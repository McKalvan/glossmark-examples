#!/usr/bin/env bash
# The agent-remit gate. The workspace is copied to a temporary git repository and
# committed; then the menu-curator subagent (GLOSS_ACTOR=agent:menu-curator, whose
# agent file is .claude/agents/menu-curator.md) makes one change inside its remit
# and one outside it. Nothing in this directory is modified.
#   SOFT  implements .MenuCatalog, conf 0.88: inside dine:Menu*, pepper:Menu*
#   HARD  implements .OrderFlow, conf 0.90: the same confidence, outside the remit
# For contrast, the allergen-auditor proposes a link inside its own remit to the
# critical allergen rule: gloss diff makes it HARD by criticality, gloss status says SOFT.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -r "$HERE" "$TMP/ws"
cd "$TMP/ws"
git init -q
git add -A
git -c user.name=demo -c user.email=demo@example.invalid commit -qm before

# The allergen-auditor's change, built under its own actor so the ledger says who wrote it.
sed -i 's|^def test_no_declaration_means_no_conflict|# @gloss? verifies dine:AllergenRule conf=0.95 id=allergen-no-declaration-test\ndef test_no_declaration_means_no_conflict|' \
  api/tests/test_allergen_guard.py
GLOSS_ACTOR=agent:allergen-auditor "$GLOSS" build -q

export GLOSS_ACTOR=agent:menu-curator
echo '$ GLOSS_ACTOR=agent:menu-curator gloss context --dir api --budget 0   # (remit lines)'
"$GLOSS" context --dir api --budget 0 | grep -E '^(Boundary|Your remit|Agent remits)'

# Inside the remit: the section grouping is part of publishing the menu.
sed -i 's|^def group_into_sections|# @gloss? implements .MenuCatalog conf=0.88 note="sections are how the menu is published"\ndef group_into_sections|' \
  api/ordering/services/menu_catalog.py
# Outside the remit: the curator reaches into the order flow to refuse 86'd lines early.
# (The marker is assembled with printf so this script holds no marker line of its own.)
printf '\n\n# %s implements .OrderFlow conf=0.9 note="refuse 86-d dishes before the order is opened"\n%s\n%s\n' \
  '@gloss?' 'def unavailable_lines(lines: list[OrderLine], items: dict) -> list[str]:' \
  '    return [items[line.menu_item_id].name for line in lines if not items[line.menu_item_id].available]' \
  >> api/ordering/services/order_flow.py

"$GLOSS" build -q
echo
echo '$ gloss diff --base HEAD'
"$GLOSS" diff --base HEAD --fail-on none
echo
echo '$ gloss status | grep allergen-no-declaration-test'
"$GLOSS" status | grep allergen-no-declaration-test
echo
echo '$ gloss context --dir api --changed   # (the "You are touching" section a new session opens with)'
"$GLOSS" context --dir api --changed | sed -n '/^## You are touching/,/^Boundary:/p' | sed '$d'
