#!/usr/bin/env bash
# Reproduces lab/ambiguous-surfaces: one table row per variant workspace.
# Read-only on the committed files: view --json goes to a temp dir.
set -uo pipefail
GLOSS="${GLOSS:-$(cd "$(dirname "$0")/../.." && pwd)/.tools/bin/gloss}"
case "$GLOSS" in /*) ;; */*) GLOSS="$(cd "$(dirname "$GLOSS")" && pwd)/$(basename "$GLOSS")" ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

declare -A SURFACES=(
  [admin-limit]="apps/admin/src/pages/CreditLimitPage.tsx"
  [server-page]="storefront/quotes/views.py"
  [cli]="tools/hpctl/hpctl/close_period.py tools/hpctl/hpctl/cli.py"
  [bff]="bff/src/routes/reorder.ts"
  [graphql]="gateway/src/resolvers.ts gateway/src/server.ts gateway/schema.graphql"
  [pdf-invoice]="services/documents/documents/invoice_pdf.py"
)

# Code files are everything except GlossMark's own files.
code_files() {
  (cd "$1" && find . -type f ! -path './.glossmark/*' ! -path './ontology/*' ! -name '.gloss.yaml' ! -name 'glossmark.yaml' | sort)
}

status=0
for case in admin-limit server-page cli bff graphql pdf-invoice; do
  variants=("$HERE/$case"/*/)
  first="${variants[0]%/}"
  # 1. The variants of a case differ only in @gloss lines, the ontology and the manifests.
  for v in "${variants[@]:1}"; do
    v="${v%/}"
    if ! diff <(code_files "$first") <(code_files "$v") >/dev/null; then
      echo "FAIL $case: $(basename "$v") has different code files from $(basename "$first")"; status=1; continue
    fi
    while read -r f; do
      if ! diff <(grep -v '@gloss' "$first/$f") <(grep -v '@gloss' "$v/$f") >/dev/null; then
        echo "FAIL $case: $f differs beyond @gloss lines in $(basename "$v")"; status=1
      fi
    done < <(code_files "$first")
  done
  # 2. One row per variant.
  echo
  echo "### $case"
  echo
  echo "| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |"
  echo "| --- | --- | --- | --- | --- | --- | --- |"
  for v in "${variants[@]}"; do
    # shellcheck disable=SC2086
    python3 -I "$HERE/measure.py" "$GLOSS" "${v%/}" "$TMP/$case" ${SURFACES[$case]} || status=1
  done
done
exit $status
