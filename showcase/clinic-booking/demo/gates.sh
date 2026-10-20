#!/usr/bin/env bash
# Shows the three gates on one change set. The workspace is copied to a temporary
# git repository, committed as the before-state, changed, and diffed with
# gloss diff --base HEAD. Nothing in this directory is modified.
#   AUTO  the signature of an accepted, marked function changes (fingerprint only)
#   SOFT  an agent proposes a link to an existing concept, inside the allowed set, conf >= 0.7
#   HARD  an agent proposes a link below soft-conf-threshold, and the published
#         cancellation window changes in code without the ontology (value-from)
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
export GLOSS_ACTOR=agent:claude-code

# AUTO: rename a parameter on the marked FindOpenSlots signature.
sed -i 's/func (s \*Service) FindOpenSlots(ctx context.Context, practitionerID uuid.UUID/func (s *Service) FindOpenSlots(ctx context.Context, practitioner uuid.UUID/' \
  services/booking-api/internal/booking/availability.go
sed -i 's/ListOpenSlots(ctx, practitionerID, from, to)/ListOpenSlots(ctx, practitioner, from, to)/' \
  services/booking-api/internal/booking/availability.go

# SOFT: a confident proposal on the HTTP handler that serves slot search.
sed -i 's|^func (h \*handlers) listSlots|// @gloss? implements .SlotSearch conf=0.88\nfunc (h *handlers) listSlots|' \
  services/booking-api/internal/httpapi/slots.go

# HARD: an unsure proposal, and the cancellation window halved in code only.
sed -i 's|^func (h \*handlers) listPractitioners|// @gloss? implements .PractitionerDirectory conf=0.5\nfunc (h *handlers) listPractitioners|' \
  services/booking-api/internal/httpapi/slots.go
sed -i 's/^const CancellationWindow = 24 \* time.Hour/const CancellationWindow = 12 * time.Hour/' \
  services/booking-api/internal/booking/cancellation.go

"$GLOSS" build -q
"$GLOSS" diff --base HEAD --fail-on none
echo
"$GLOSS" drift --fail-on none | grep -A2 -i 'value' || true
