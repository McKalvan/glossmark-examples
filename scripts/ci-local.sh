#!/usr/bin/env bash
# Run every showcase check locally, exactly as .github/workflows/showcase.yml does.
# UPDATE=1 rewrites the golden files.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
sh "$ROOT/scripts/install-gloss.sh" >/dev/null
status=0
while IFS=$'\t' read -r root fail_on action coverage; do
  case "$root" in ''|\#*) continue ;; esac
  "$ROOT/scripts/check-workspace.sh" "$root" "$fail_on" || status=1
done < "$ROOT/showcase/workspaces.tsv"
while IFS=$'\t' read -r dir fail_on repos; do
  case "$dir" in ''|\#*) continue ;; esac
  # shellcheck disable=SC2086
  "$ROOT/scripts/check-landscape.sh" "$dir" "$fail_on" $repos || status=1
done < "$ROOT/showcase/landscapes.tsv"
exit $status
