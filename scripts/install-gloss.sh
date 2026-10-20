#!/usr/bin/env sh
# Install the pinned GlossMark release into .tools/bin (or $GLOSS_INSTALL_DIR).
# Every script in this repository runs that binary, never one from PATH.
set -eu
VERSION="${GLOSS_VERSION:-v0.1.0}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIR="${GLOSS_INSTALL_DIR:-$ROOT/.tools/bin}"
if [ -x "$DIR/gloss" ] && "$DIR/gloss" version | grep -qx "gloss ${VERSION#v}"; then
  echo "install-gloss: gloss ${VERSION} already in $DIR"
  exit 0
fi
# The installer is fetched from the release tag, so it is pinned too.
curl -fsSL "https://raw.githubusercontent.com/mckalvan/glossmark/${VERSION}/install.sh" \
  | GLOSS_INSTALL_DIR="$DIR" sh -s -- "$VERSION"
"$DIR/gloss" version
