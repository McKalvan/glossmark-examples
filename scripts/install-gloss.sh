#!/usr/bin/env sh
# Install the pinned GlossMark into .tools/bin (or $GLOSS_INSTALL_DIR).
# Every script in this repository runs that binary, never one from PATH.
#
# The pin lives in GLOSS_REF at the repository root (override with $GLOSS_VERSION):
#   vX.Y.Z    a release; the release binary is downloaded
#   <commit>  a commit on GlossMark main; built with go install (needs Go 1.24)
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION="${GLOSS_VERSION:-$(sed -n '/^[^#]/{p;q;}' "$ROOT/GLOSS_REF")}"
DIR="${GLOSS_INSTALL_DIR:-$ROOT/.tools/bin}"
STAMP="$DIR/gloss.ref"
if [ -x "$DIR/gloss" ] && [ "$(cat "$STAMP" 2>/dev/null)" = "$VERSION" ]; then
  echo "install-gloss: gloss ${VERSION} already in $DIR"
  exit 0
fi
mkdir -p "$DIR"
case "$VERSION" in
  v*)
    # The installer is fetched from the release tag, so it is pinned too.
    curl -fsSL "https://raw.githubusercontent.com/mckalvan/glossmark/${VERSION}/install.sh" \
      | GLOSS_INSTALL_DIR="$DIR" sh -s -- "$VERSION"
    ;;
  *)
    GOBIN="$DIR" go install "github.com/mckalvan/glossmark/cmd/gloss@${VERSION}"
    ;;
esac
echo "$VERSION" >"$STAMP"
"$DIR/gloss" version
