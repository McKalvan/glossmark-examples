# Hypothesis: cross-cutting concerns

## The question

Authentication, rate limiting, feature flags and logging touch every request. Where do they belong in GlossMark's two tiers? Are they core concepts, `internal` implementation concepts, capabilities or constraints? And how does a repository say "this handler is protected by auth" without a marker on every handler, when the middleware, decorators and config for these concerns appear in dozens of files?

## Why it matters

Every service has these concerns, and they are where the riskiest one-line changes happen. Deleting `@requires_role("approver")` from a handler is a security incident. A tool that classifies review by criticality should notice that edit. A tool that counts markers should not push an adopter into writing four markers above every handler.

## The experiment

One small Flask service, the Tallyfern expense claims API, is modelled three ways side by side. The code is identical in all three; only the markers, ontology and manifests differ.

- **Platform-only** in `variant-a-platform-only/`. Each concern is one `internal` implementation concept. It is marked once on its platform module with `scope=file`, once on its config file and once on its test. Handlers carry only their domain markers.
- **Every handler** in `variant-b-every-handler/`. The platform modules are marked as in the platform-only variant, and every handler also carries an `implements` marker for each concern that applies to it. Authentication is no longer internal: it realizes a core `exp:AccessControl` capability.
- **Constraints** in `variant-c-constraints/`. Access control is a core `constraint` that `constrains` the four business processes. The mechanisms name the handlers they apply to with a custom ontology relation `guards`. The platform layer is its own `component` boundary. The rate limit and the feature flag are internal constraints whose values are bound to the YAML config with `publishes-value`.

The service has five decorated handlers in `service/app/handlers/claims.py`, one flagged export, one public health check, four platform modules, three config files and three test files.

## What "GlossMark handles this well" would look like

1. **A home for each concern.** The four concerns can be modelled without `gloss check` errors or warnings in a way that keeps the core tier business-readable. `check` prints `0 errors, 0 warnings` and `drift` prints `Violations: 0   Gaps: 0` in every variant.
2. **Protection without per-handler markers.** There is a way to state "these handlers are protected by auth" once, in the ontology or a manifest, and `gloss impact` on a handler file says so (for example `guarded by xapi:BearerAuthentication`).
3. **Blast radius.** `gloss impact service/app/platform/auth.py` lists the concepts, and ideally the files, that the auth module protects.
4. **Criticality flows.** Auth is `high`. `impact` on the auth module reports `criticality high`. A guarded handler is reviewed with that in mind, and `gloss diff` raises a change that removes a guard.
5. **Removing a guard is visible.** Deleting `@requires_role("approver")` from `approve_claim` makes the link stale or produces a `gloss diff` line. It does not report `no ontology-relevant changes`.
6. **Marker noise is caught.** In the every-handler variant, `gloss check` reports GM131 for `.Authentication` repeated on five consecutive handlers. The remedy it suggests, one `scope=block` marker above the run, is achievable.
7. **Untested concerns show up.** If the only test of a `high` concern is deleted, `gloss drift` lists it as untested, or `gloss coverage` drops.
8. **Agents are told.** `gloss context --dir service/app/handlers` tells an agent that the handlers there are protected by auth and rate limited.
9. **Config values are bound.** The rate limit and the flag live in YAML. `value-from` on a YAML key binds them, and flipping the flag reports `value-drift`.
10. **A relation for "applies to" or "guards".** GlossMark ships one, or a custom relation declared under `relations:` is understood by `impact` and `context`.

Every outcome is checked in [FINDINGS.md](FINDINGS.md), and [run.sh](run.sh) reproduces each one.
