# Findings: cross-cutting concerns

All output below comes from the v0.1.0 binary (`$GLOSS`). [run.sh](run.sh) reproduces every block from this directory on temporary copies; the section numbers in the repros are its section headers.

## Verdict

GlossMark v0.1.0 gives each concern a sensible home, but it cannot say "this handler is guarded by auth". It also does not notice when a guard is removed, which is the change that matters most. The cleanest model is the constraints variant: a core `constraint` for access control, internal implementation concepts for the mechanisms, and `constrains` edges. `impact` follows `constrains` in both directions. Criticality and `context` ignore it, though, and a custom `guards` relation reaches only the graph. The only way to get a file-level blast radius is to write `implements` on the guarded code, which is untrue. Writing it on every handler also slips past the GM131 noise check, because a second marker stacked on a declaration hides the run.

**The three variants side by side** (run.sh section 0, plus section 12 for the `scope=file` probe):

| | Platform-only (A) | Every handler (B) | Constraints (C) | A + `scope=file` auth on handler files |
| --- | --- | --- | --- | --- |
| Markers in total | 19 | 33 | 21 | 21 |
| Markers for the four concerns | 9 | 23 (14 on handlers) | 11 | 11 |
| `check` | 0 errors, 0 warnings | 0 errors, 0 warnings (no GM131) | 0 errors, 0 warnings | 0 errors, 0 warnings (no GM130) |
| `drift` | 0 violations, 0 gaps, 2 untested | 0 violations, 0 gaps, 2 untested | 0 violations, 0 gaps, 2 untested | same as A |
| Concept coverage | 2 of 5 (internal concerns not counted) | 3 of 6 | 3 of 6 | 2 of 5 |
| `impact` on `auth.py` names the handlers | no | files: `also linked from: claims.py, exports.py` | concepts: `exp:AccessControl ... constrains exp:ClaimApproval, exp:ClaimExport, ...` | files, as B |
| Criticality of `list_my_claims` | unclassified | high (from `xapi:Authentication`) | unclassified | unclassified (the file artifact is high) |
| Deleting `@requires_role("approver")` | gate AUTO, no change | gate AUTO, no change | gate AUTO, no change | not run |

GM130 was never a factor. A file-level auth marker targets the concern, and the symbol markers in the same file target domain concepts, so they never share a relation and target.

**The hypothesis, item by item:**

1. **A home for each concern: met.** All three variants check clean with zero violations and zero gaps. Logging and flags fit as `internal` mechanisms. Access control fits as a core constraint. Rate limits and flag states fit as internal constraints with values. An `internal` concept can carry a declared criticality: `xapi:Authentication (process, implementation, high)` in A.
2. **Protection without per-handler markers: partly met.** `constrains` on a core constraint reaches `impact` on the handler file: `exp:ClaimApproval (process, core, high): constrained by exp:AccessControl`. It works at the concept level only, and nothing says which mechanism or file does the guarding ([F-XCUT-2](#f-xcut-2-there-is-no-relation-for-guards-or-applies-to-and-a-custom-one-is-inert)).
3. **Blast radius: partly met.** It appears as files only when the guarded code falsely `implements` the guard (B, or two `scope=file` markers), and as concepts through `constrains` (C).
4. **Criticality flows: partly met.** `impact` on the auth module says `criticality high` in every variant. `constrains` carries no criticality to what it constrains. B raises every handler to high, but only because each handler claims to implement authentication.
5. **Removing a guard is visible: not met.** In every variant the result is `gate AUTO` and `no ontology-relevant changes` ([F-XCUT-1](#f-xcut-1-deleting-a-guard-decorator-is-invisible-to-every-command)).
6. **Marker noise is caught: not met.** B has `.Authentication` on five consecutive handlers and gets no GM131 ([F-XCUT-4](#f-xcut-4-gm131-misses-a-repeated-marker-when-a-second-marker-is-stacked-on-each-declaration)). The suggested `scope=block` remedy cannot span Python functions ([F-XCUT-5](#f-xcut-5-gm131s-remedy-scopeblock-cannot-span-a-run-of-python-functions)).
7. **Untested concerns show up: not met for internal concepts** ([F-XCUT-3](#f-xcut-3-internal-concepts-drop-out-of-coverage-and-untested-whatever-their-criticality)). Only `impact` notices.
8. **Agents are told: not met.** `context --dir service/app/handlers` has 0 lines that mention `constrains` or `guards`.
9. **Config values are bound: partly met.** `publishes-value` on a YAML line works. Flipping the flag gives `value-drift` and a HARD gate. `value-from: symbol` never finds a YAML key ([F-XCUT-6](#f-xcut-6-value-from-symbol-never-matches-a-yaml-key)).
10. **A relation for "guards": not met.** A custom relation declared under `relations:` is validated: an undeclared one gives GM200, and a missing target gives GM215. It is written to the graph, and `impact`, `context` and `drift` never read it.

**What worked well.** `internal: true` with a declared `criticality` is a good home for mechanisms the business never names. `impact` renders `constrains` in both directions without any configuration. Value binding on an internal constraint in YAML works with the `publishes-value` marker. A flag flip is a HARD, `LOW`-tagged change, as it should be for a governed setting. A separate platform boundary (`tally:request-platform`) inherits `high` from the constraint it realizes and needed no extra markers. Custom relations are checked for dangling targets.

**What an adopter should do today.** Use the constraints variant's ontology. Do not mark handlers for cross-cutting concerns. Bind flag and limit values with `publishes-value` lines. Add one `scope=file` `implements` marker for the guard on each handler file only if the file-level blast radius in `impact` is worth two costs. The link is semantically wrong, and every edit to the file makes it stale (C20, F-ADOPT-8).

**Already known, not re-reported.** Every edit to a `scope=file` config or handler file makes its link stale ([F-ADOPT-8](../FINDINGS-ADOPTION.md#f-adopt-8-accepting-a-scopefile-proposal-makes-it-stale-and-it-cannot-be-re-confirmed), C20). In section 7, the flag flip shows two stale links next to the value drift. One small new piece is that the line-scoped `publishes-value` marker goes stale on the very edit that `value-drift` already reports. That gives four `gloss diff` lines for one changed value.

## F-XCUT-1: Deleting a guard decorator is invisible to every command

**Problem.** Cross-cutting concerns live in decorators: `@requires_role("approver")`, `@rate_limit("claims-write")`, `@feature("bulk_export")`. The declaration detector skips the decorator stack to find the anchor, and the anchor fingerprint covers only the signature line. Deleting a guard therefore changes no link, makes nothing stale, and `gloss diff` reports gate AUTO with no ontology-relevant changes. That holds even when the handler's concept is `high` and even in the variant where the handler carries an explicit `implements .Authentication` marker. Changing the `def` line of the same handler is caught at once. The riskiest one-line change in a web service is the one GlossMark cannot see.

**Repro.** `run.sh` section 1 commits each variant to a temporary git repository, deletes the `@requires_role("approver")` line above `approve_claim`, rebuilds and runs `gloss diff --base HEAD`:
```
--- variant-b-every-handler: 0 1 service/app/handlers/claims.py
Ontology impact — r1-variant-b-every-handler   base HEAD   gate AUTO
  no ontology-relevant changes
Views changed: none
```
The contrast in the same section changes only the `def` line:
```
Ontology impact — r1b   base HEAD   gate AUTO   criticality high
~ implements xapi:ClaimDecisionHandler anchor signature changed   service/app/handlers/claims.py:approve_claim   [HIGH, AUTO]
~ stale implements .ClaimDecisionHandler                       service/app/handlers/claims.py                 [AUTO]
```

**Proposed change.** Include the normalized decorator or annotation stack in the fingerprint of a `symbol`-scoped anchor. The detector already parses that stack in order to skip it. Then report a stack change in `gloss diff` as `decorators changed` with the artifact's criticality. With F-XCUT-2, a change to the stack of an artifact whose concept is guarded is at least SOFT.

**Done when.** In run.sh section 1, `gloss diff --base HEAD` lists `implements xapi:ClaimDecisionHandler ... service/app/handlers/claims.py:approve_claim [HIGH ...]` instead of `no ontology-relevant changes`, in all three variants.

## F-XCUT-2: There is no relation for "guards" or "applies to", and a custom one is inert

**Problem.** GlossMark has no way to say "mechanism X applies to concepts Y and Z", the defining shape of a cross-cutting concern. Three workarounds were tried.

- **`implements` on each guarded handler** (variant B) is false: the handler is not the mechanism of authentication. It gives `impact` a file-level blast radius, but it costs 14 extra markers for five handlers. It also raises every handler to the guard's criticality through the wrong edge.
- **`constrains`** from a core constraint (variant C) is the closest built-in relation. `impact` renders it both ways. Criticality does not flow along it, `impact` lists concepts and not files, and `context` never mentions it.
- **A custom `guards` relation** declared under `relations:` passes `check`. It is validated, with GM200 when undeclared and GM215 for a missing target, and is written to the graph. `impact`, `context` and `drift --all` never mention it.

**Repro.** `run.sh` section 2, on `variant-c-constraints`:
```
guards edges in the graph: 7
impact of claims.py, lines naming constrains or guards:
  exp:ClaimApproval (process, core, high): constrained by exp:AccessControl
  ...
  xapi:SubmitClaimHandler (process, implementation): realizes exp:ClaimSubmission; constrained by xapi:ClaimWriteRateLimit
impact of auth.py, lines naming constrains or guards:
  exp:AccessControl (constraint, core, high): constrains exp:ClaimApproval, exp:ClaimExport, exp:ClaimHistory, exp:ClaimSubmission
context --dir service/app/handlers, lines naming constrains or guards: 0
```
Section 0 shows criticality. With `exp:AccessControl` at `high` and `constrains` on all four processes, `list_my_claims` stays unclassified in C. In B it is `high (from xapi:Authentication)`.

**Proposed change.** Add a built-in ontology relation `guards`, with `applies-to` as an alias, from a mechanism or constraint to the concepts it applies to. Add a manifest key `guarded-by: [xapi:BearerAuthentication]` meaning "every artifact under this directory is guarded by X", so one line covers a handler directory. Give both these semantics:
- `impact` on a guard's files lists the guarded concepts and their artifact files.
- `impact` on a guarded file prints `guarded by xapi:BearerAuthentication (high)`.
- `context` lists the guards that apply to the directory.
- `gloss diff` tags a change to a guarded artifact with the guard's criticality, as a review level only, never inherited as the artifact's own level.
- `constrains` gets the same `impact`/`context` treatment it has in `impact` today.

A custom relation could opt in with `relations: { guards: { surfaces: [impact, context] } }`.

**Done when.** In `variant-c-constraints` with `guards` as written, `$GLOSS impact service/app/handlers/claims.py` prints `guarded by xapi:BearerAuthentication`, and `$GLOSS impact service/app/platform/auth.py` lists `service/app/handlers/claims.py`. `$GLOSS context --dir service/app/handlers | grep -c guard` is at least 1.

## F-XCUT-3: Internal concepts drop out of coverage and untested, whatever their criticality

**Problem.** `internal: true` is the natural home for auth, rate limiting, flags and logging when the business does not name them. Internal concepts are excluded from the concept-coverage denominator and from the `untested` finding. A `high` internal concept can therefore lose its only test with no change to `drift` or `coverage`. Only `impact` notices. Declaring `criticality: high` on the concept changes nothing.

**Repro.** `run.sh` section 3 deletes `service/tests/test_auth.py` from `variant-a-platform-only`:
```
  exp:ClaimExport is implemented but nothing tests or verifies it  [ontology/exp.gloss.yaml:20]
  exp:ClaimHistory is implemented but nothing tests or verifies it  [ontology/exp.gloss.yaml:17]
Concepts covered 40% (2/5 with an artifact and a verifier) ...   Untested: 2
service/app/platform/auth.py  [SOFT, tally:expenses-api, criticality high]
  xapi:Authentication (process, implementation, high)
      ! no tests or verifies link; consider adding one
```
The untested list and coverage are the same as with the test present. Making one concern non-internal grows the denominator: `2 of 6 implementation concepts`.

**Proposed change.** Report `untested` for an internal concept whose effective criticality is `high` or `critical`, and count such concepts in concept coverage. Alternatively, report every internal concept under a separate `internal untested` line that is not counted in the headline percentage. Document either rule in ADVANCED.md.

**Done when.** In run.sh section 3, `drift` lists `xapi:Authentication is implemented but nothing tests or verifies it`.

## F-XCUT-4: GM131 misses a repeated marker when a second marker is stacked on each declaration

**Problem.** GM131 is meant to catch per-handler marker noise. As observed, it fires only when three consecutive marker lines are identical. When each declaration carries two markers, the same marker on three consecutive declarations gives no warning. That is the normal shape when handlers are marked for a cross-cutting concern on top of their domain concept. Variant B has `implements .Authentication` and `implements .RequestLogging` on five consecutive handlers and checks clean. A two-target marker repeated three times does warn, but the message names only its first target.

**Repro.** `run.sh` section 4:
```
--- one identical marker on three functions
...probe131.py:5: warning: implements xapi:RequestLogging is repeated on 3 consecutive declarations (lines 5-15); ... [GM131]
--- the same, with a second identical marker stacked on each
gloss check: 0 errors, 0 warnings
--- one identical two-target marker on three functions
...probe131.py:5: warning: implements xapi:ClaimQueries is repeated on 3 consecutive declarations (lines 5-15); ... [GM131]
--- variant-b-every-handler as committed (.Authentication on 5 consecutive handlers):
gloss check: 0 errors, 0 warnings
```

**Proposed change.** Group markers by the declaration they anchor to. Warn when one relation and target pair appears on three or more consecutive declarations, whatever else is stacked on them. Name every repeated target.

**Done when.** `cd variant-b-every-handler && $GLOSS check` reports GM131 for `xapi:Authentication` and `xapi:RequestLogging` in `service/app/handlers/claims.py`, and the stacked probe in section 4 warns.

## F-XCUT-5: GM131's remedy (scope=block) cannot span a run of Python functions

**Problem.** GM131 says "one marker with scope=block above the run ... says the same with one edge". In Python, `scope=block` above the first of several module-level functions anchors only that function. Above a decorated handler, the anchor range also starts at the `def` line and leaves out the decorators. There is no scope that covers "these five handlers", so the advice cannot be followed for Python handlers.

**Repro.** `run.sh` section 5:
```
  anchor service/app/handlers/claims.py submit_claim lines 21-35
  anchor service/app/handlers/probe_block.py one lines 2-3
```
`probe_block.py` has three functions on lines 2 to 9, and the block covers the first one only.

**Proposed change.** Make GM131's hint depend on the language and the anchor kind. Where a block cannot span the run, suggest one marker on the shared entry point, a `scope=file` marker, or a manifest-level `guarded-by:` (F-XCUT-2). Alternatively, add a `scope=section` that runs from the marker to the next marker line or the end of the file.

**Done when.** The GM131 message on the section 4 probe suggests something that, when applied, removes the warning and keeps one edge per concept.

## F-XCUT-6: value-from symbol never matches a YAML key

**Problem.** Rate limits and flag states live in YAML config. `value-from: { path, symbol }` cannot find a YAML key in any form tried: a nested key, a top-level key, or a dotted path. `line:` works, and so does a `publishes-value` marker above the line. The GM360 message says the symbol "is not assigned anywhere", which reads as a typo rather than an unsupported file type.

**Repro.** `run.sh` section 6, on `variant-c-constraints`:
```
--- nested key per_minute:
ontology/xapi.gloss.yaml:38: error: xapi:ClaimWriteRateLimit: value-from symbol "per_minute" is not assigned anywhere in service/config/ratelimit.yaml [GM360]
--- top-level key claims_write_per_minute:
... value-from symbol "claims_write_per_minute" is not assigned anywhere ... [GM360]
--- dotted path policies.claims-write.per_minute:
... [GM360]
--- line: 5:
gloss check: 0 errors, 0 warnings
```

**Proposed change.** Resolve `symbol` in YAML, TOML and JSON as a dotted key path (`policies.claims-write.per_minute`), and accept a bare key when it is unique in the file. Until then, have GM360 say that `symbol` is not supported for the file type, and suggest `line:` or a `publishes-value` marker.

**Done when.** In section 6, the nested-key and dotted-path variants check clean, and flipping the value reports `value-drift`.

## F-XCUT-7: criticality suggest proposes high for internal engineering constraints

**Problem.** Modelling a rate limit or a flag as a `constraint` is the only way to give it a governed value. `criticality suggest` then proposes `high` for each one with the reason "a rule the business relies on", although both are `internal: true`, which by definition the business does not see. A reviewer has to declare a lower level on every internal constraint to silence it. In this experiment, `variant-c-constraints` declares `medium` and `low` with a comment.

**Repro.** `run.sh` section 8 removes the two reviewed levels:
```
  xapi:BulkExportFlag → high  (constraint: a rule the business relies on)
  xapi:ClaimWriteRateLimit → high  (constraint: a rule the business relies on)
```

**Proposed change.** Do not propose a level for an internal constraint on the "constraint" rule alone. Propose it only when it is published or security-verified, or word the reason as "engineering constraint; classify if it matters".

**Done when.** Section 8 prints `0 suggestions` or an engineering-constraint reason.

## F-XCUT-8: impact says core concepts have no tests when drift says they do

**Problem.** `gloss impact` prints `! no tests or verifies link; consider adding one` under every core concept whose implementation concept is verified. `drift` correctly does not list those concepts as untested. In the cross-cutting case this hits the constraint itself: `impact` on the auth module in variant B tells the reviewer `exp:AccessControl` has no tests, while `xapi:Authentication`, which realizes it, is verified two lines below.

**Repro.** `run.sh` section 9, on `variant-a-platform-only`: `impact service/app/handlers/claims.py` prints the hint under `exp:ClaimApproval`. Meanwhile `drift | grep -c 'ClaimApproval is implemented but nothing tests'` prints `0`, because `test_claims.py` verifies `xapi:ClaimDecisionHandler`.

**Proposed change.** Have `impact` count a verifier of any concept that realizes a core concept, which is the rule `drift` uses, and print `tests (via xapi:ClaimDecisionHandler): service/tests/test_claims.py`.

**Done when.** Section 9 prints no hint under `exp:ClaimApproval`.

## F-XCUT-9: impact --base reports an empty base summary

**Problem.** `gloss impact --base HEAD` prints `Concepts covered 0% → 50%   Files 0% → 75%`, and its JSON `before` block is all zeros. `gloss diff --base HEAD` on the same tree prints `50% → 50%`. A reviewer reading `impact` sees a change that appears to create all the coverage.

**Repro.** `run.sh` section 11, on `variant-b-every-handler` in a temporary git repository with a one-line change:
```
impact: Concepts covered 0% → 50%   Files 0% → 75%   ...
diff:   Concepts covered 50% → 50%   Files 75% → 75%   ...
impact.before: {'concepts_in_scope': 0, 'concepts_covered': 0, 'covered_files': 0}
```

**Proposed change.** Compute `impact`'s base summary the way `diff` does, or omit it when it is not computed.

**Done when.** Both lines in section 11 print `50% → 50%`.

## F-XCUT-10: an undeclared custom relation is reported once per target

**Problem.** Writing a custom relation without declaring it under `relations:` gives the right error, GM200. It repeats once per target on the same line, so two concepts with seven targets in all produce seven identical errors, each listing all 31 known relations.

**Repro.** `run.sh` section 10:
```
ontology/xapi.gloss.yaml:28: error: unknown relation "guards"; declare it under relations: in an ontology file ...
ontology/xapi.gloss.yaml:28: error: unknown relation "guards"; declare it under relations: in an ontology file ...
(4 times for line 28, 3 times for line 33)
gloss check: 7 errors, 0 warnings
```

**Proposed change.** Report GM200 once per key occurrence.

**Done when.** Section 10 prints 2 errors.
