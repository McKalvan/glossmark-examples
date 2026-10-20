#!/usr/bin/env bash
# A read-only tour of the commands this example owns. Writes only to a temporary
# directory (the viewer, the SQLite export, the PROV-O ledger).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
OUT=$(mktemp -d)
cd "$HERE"
step() { printf '\n$ gloss %s\n' "$*"; "$GLOSS" "$@"; }
step version
step check --explain
step coverage
step criticality suggest
step impact services/booking-api/internal/booking/cancellation.go apps/web/app/waitlist/page.tsx
step view -o "$OUT/viewer.html"
step export --sqlite "$OUT/graph.db"
step export --prov "$OUT/prov.jsonld"
if command -v sqlite3 >/dev/null; then
  echo; echo "\$ sqlite3 graph.db  # files that deserve the most careful review"
  sqlite3 "$OUT/graph.db" "SELECT path, criticality FROM nodes WHERE node='artifact' AND criticality IN ('high','critical') ORDER BY path;"
fi
step doctor || true
echo; echo "viewer: $OUT/viewer.html"
