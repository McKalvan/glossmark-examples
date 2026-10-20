#!/usr/bin/env bash
# What `gloss coverage --fail-under current` does in the three situations CI meets.
# The workspace is copied into a temporary git repository at the same depth as in
# this repository (showcase/library-legacy), so path handling matches CI.
#   (a) push to main: the base already has this workspace and its graph
#   (b) first PR: the base does not contain the workspace at all
#   (c0) a PR that removes a test marker whose concept another test still verifies
#   (c) a PR that lowers concept coverage (a test marker removed)
#   (d) no origin/main ref at all (a clone without the remote-tracking branch)
# Then --changed-only and --fail-under-files on the same states.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GLOSS="${GLOSS:-$ROOT/.tools/bin/gloss}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GLOSS_ACTOR=agent:claude-code
git_() { git -c user.name=demo -c user.email=demo@example.invalid "$@"; }
run() { printf '\n$ gloss %s\n' "$*"; "$GLOSS" "$@"; echo "exit $?"; }

cd "$TMP" && git init -q && echo "# repo" > README.md && git_ add -A && git_ commit -qm "base without the workspace"
mkdir -p showcase && cp -r "$HERE" showcase/library-legacy
git_ add -A && git_ commit -qm "adopt GlossMark in library-legacy"
git update-ref refs/remotes/origin/main HEAD          # what CI sees on a push to main
cd showcase/library-legacy

echo "== (a) push to main: base = origin/main = HEAD, which has the workspace and its graph"
run coverage --fail-under current

echo; echo "== (b) first PR: base = HEAD~1, which has no showcase/library-legacy"
run coverage --fail-under current --base HEAD~1

echo; echo "== (c0) a PR deletes the verifies marker on HoldQueueTest (features/holds.feature still verifies hold trapping)"
sed -i '/@gloss verifies .HoldQueue/d' src/test/java/gov/riverbend/circ/service/HoldQueueTest.java
"$GLOSS" build -q
run coverage --fail-under current --base HEAD
git checkout -q -- . && "$GLOSS" build -q

echo; echo "== (c) a PR deletes the only test marker on FineCalculatorTest (the legacy 'tests' one)"
sed -i '/@gloss tests .DeskFineCalculator/d' src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java
"$GLOSS" build -q
run coverage --fail-under current --base HEAD

echo; echo "== (d) the same change, but origin/main does not exist"
git update-ref -d refs/remotes/origin/main
run coverage --fail-under current
git update-ref refs/remotes/origin/main HEAD

echo; echo "== --changed-only: file coverage over the files changed since the base"
run coverage --changed-only --base HEAD
run coverage --changed-only --base HEAD~1
run coverage --changed-only --fail-under-files 50 --base HEAD

echo; echo "== --fail-under-files"
git checkout -q -- . && "$GLOSS" build -q
run coverage --fail-under-files 60
run coverage --fail-under-files 80
