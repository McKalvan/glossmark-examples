# Lab status at GlossMark main 0be26e3

Re-check of every finding in `lab/*/FINDINGS.md` and `lab/FINDINGS-ADOPTION.md` against GlossMark main at `0be26e3` (merge of PR #255), 2026-10-28.

The findings were written against v0.1.0. The lab was last run with `e24677c` (PR #169). Every finding issue except #65 was closed on 2026-10-20 or 2026-10-21, before `e24677c`. So the old and new runs mostly agree, and both differ from the FINDINGS text.

**How it was checked.** `GLOSS=.tools/bin/gloss lab/<x>/run.sh` for every experiment, compared with the same run using the `e24677c` binary. The Done-when of each finding was then reproduced on scratch copies outside the repository. `lab/` was never written. Where a `run.sh` section no longer measures what it says, the evidence comes from the scratch repro, and [Lab maintenance](#lab-maintenance) gives the reason. The Upstream column gives the issue, then the PR that closed it with its merge commit.

Totals: 75 fixed, 0 still present, 4 changed, 3 not re-checkable.

## ambiguous-surfaces

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-SURF-1 | fixed | `admin-limit/a-presents`: artifact `criticality` null and `impact` header `[SOFT, hpb:admin]` agree; check adds GM224 (`presents` on a constraint, suggests `configures`) | #47, PR #140 (128cbd3) |
| F-SURF-2 | fixed | `hp:OrderPlacement` is in `hpb:harbor` in both `bff/a-implements` and `bff/e-impl-bff`; `admin-limit/b-implements` places `hp:CreditLimit` in `hpb:harbor`, not `hpb:admin` | #48, PR #145 (9b33c05) |
| F-SURF-3 | fixed | Copy of `server-page/a-implements` with `presents:` and `realizes: []` reports `hpb:storefront now implements hp:Pricing, which its manifest does not allow`, plus a gap that says "its code implements it instead" | #49, PR #145 |
| F-SURF-4 | fixed | `cli/e-hosts-only`: GM223 at `close_period.py:10`, drift `hp:PeriodClose is hosted ... but nothing implements it`, `export --status` says `unimplemented` | #50, PR #145 |
| F-SURF-5 | fixed | `admin-limit/c-configures` with `configures: [hp:CreditLimit]` in the manifest: 0 warnings, and the graph has a declared and a derived `hpb:admin configures hp:CreditLimit` edge | #51, PR #145 |
| F-SURF-6 | fixed | `pdf-invoice/c-implements` with the verifier removed: coverage `1 of 2`, `untested: hpx:InvoiceDocument` (the tests of hp:Invoicing "sit in boundaries that hold none of its code") | #52, PR #140 |
| F-SURF-7 | fixed | `server-page/a-implements`: `coverage --fail-under 50` prints `100% (1 of 1 ...)` and exits 0; an empty scope prints `n/a` | #53, PR #145 |
| F-SURF-8 | fixed | `graphql/d-schema-represents`: no derived `holds` edge from the gateway, and `hp:Order` is in `hpb:orders`. GM503 now suggests `allowed: [derived, hp:Order]` rather than `presents` (ADR 0037) | #54, PR #145 |
| F-SURF-9 | fixed | MARKING.md "Pages and shells" now gives the decision table (inline `presents` vs a page concept). `server-page/b-presents` is still never `untested`, which matches the docs | #55, PR #145 |
| F-SURF-10 | fixed | After a rebuild, the `hpb:mobile-bff` node is `high` in `bff/a-implements` and unclassified in `bff/b-presents`; `run.sh` still shows `critical` because it reads the committed graph | #56, PR #145 |
| F-SURF-11 | fixed | Workspace holding only `schema.graphql` with no `comment-styles`: `gloss build: 1 files scanned, 1 marker` | #57, PR #145 |

## concept-poor-legacy

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-POOR-1 | changed | Docstrings, tables and test calls are now read: `test_doIt`/`test_process_data` get `verifies [calls:...]`, and `process_data` gets `[doc:count]`. Only 1-2 of the 5 docstring surfaces are right at default `--min-conf`, `zz1`/`zz2` fall below it (they appear only in a scope=file collapse at `--min-conf 0.01`), and `test_ok` gets nothing | #58, PR #150 (4882375) |
| F-POOR-2 | fixed | The probe prints nothing for `ent`/`plen`/`nish`/`process`/`handler`. The aliases variant (allowed set opened) makes 5 proposals, all useful, with none on `Handler`/`handle`/`h`/`app`/`Manager`; precision is 100 % at every `--min-score` | #59, PR #150 |
| F-POOR-3 | fixed | The alias probe proposes `core/Manager.py run_batch`, `Manager.doIt`, `Processor.py grade` and `StringUtils.java check` | #60, PR #150 |
| F-POOR-4 | fixed | `run.sh`: `artifact nodes for core/handlers.py: 2`, `#InboundHandler.process`/`#OutboundHandler.process`, `core/k.ts#Inbound.process`/`#Outbound.process` | #61, PR #139 (36f6416) |
| F-POOR-5 | fixed | A rejected `@gloss?` left in `app.py` is an orphan again (no GM503, no violation, drift exit 0). After `reject --remove` and a build the ledger says `rejected`, and suggest prints `1 skipped (rejected before)` | #62, PR #142 (b04fc30) |
| F-POOR-6 | fixed | `sql/.gloss.yaml` with `holds: [..., wh:CountVariance]` and no `allowed:`: check 0 warnings, and drift does not mention CountVariance | #63, PR #145 |
| F-POOR-7 | changed | The hint (`wh: has 0 concepts; write the core tier first`), JSON `"proposals": []` and init (no `core/` or `utils/` manifest) are fixed. `suggest --concepts` on the stripped `opstool` gives one 22-member cluster, `wh:NEW:Back`, instead of a returns cluster (see R5) | #64, PRs #150, #151 (2e25776) |

## confidence-calibration

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-CAL-1 | not re-checkable | Needs relabelling: the regenerated batches (clinic 35, meterworks 22/21 proposals) share no rows with `data/labels.csv`. Upstream's own figure, printed by every suggest run, is `precision 84.0%, 46.2% of proposals`, so the gate is still unmet by its own measure | #65 (open) |
| F-CAL-2 | fixed | Section 3: `0 warnings` (no GM503, no GM131) for all four variants. With a written `allowed: [derived, X]`, suggest drops nothing and adds one proposal | #66, PR #150 |
| F-CAL-3 | fixed | The Done-when alternative is met: `suggest -h` lists the relations and file types it covers. The stripped clinic batch now has `presents` 6, `deploys` 1 and `documents` 1, in one `.md` and one `.yaml` file; `hosts`/`consumes` do not occur here, and `configures` is documented as never proposed | #67, PR #150 |
| F-CAL-4 | fixed | The stripped clinic batch has no proposal on `booking`/`httpapi`/`outbox`/`store` and none in `fake_test.go`; meterworks has no `impl`-block duplicate | #68, PR #150 |
| F-CAL-5 | not re-checkable | Monotone precision needs labels. Mechanically, `conf` now takes 13 values (0.30 to 0.97), and a 0.1-step sweep from 0.5 changes the selected set at every step | #69, PR #168 (4db53d7) |
| F-CAL-6 | fixed | Two identical `@gloss?` lines above `type Relay`: GM132 at line 13 before accept, then one `accept` rewrites both lines and `status` no longer lists the id | #70, PR #142 |
| F-CAL-7 | fixed | `--min-score` is deprecated, equal to `--min-conf score/110`. `--min-score 60` on clinic-na has a lowest conf of 0.57 | #71, PR #137 (2596eab) |

## cross-cutting-concerns

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-XCUT-1 | fixed | Section 1 lists `implements xapi:ClaimDecisionHandler decorators changed: removed @requires_role("approver") ... [HIGH, ...]` in all three variants | #72, PR #147 (3e3fd7a) |
| F-XCUT-2 | fixed | Section 2: impact on `claims.py` prints `guarded by xapi:BearerAuthentication (high)`, impact on `auth.py` lists `guarded code: service/app/handlers/claims.py, ...`, and the context grep count is 1 | #73, PR #147 |
| F-XCUT-3 | fixed | `variant-a` without `test_auth.py`: drift lists `xapi:Authentication: nothing tests or verifies it`, and Untested goes 2 → 3 | #74, PR #147 |
| F-XCUT-4 | fixed | Section 4: the stacked probe warns, and `variant-b` warns `implements xapi:Authentication, xapi:RequestLogging is repeated on 5 consecutive declarations` | #75, PR #139 |
| F-XCUT-5 | fixed | The GM131 hint now proposes `scope=file` or the shared entry point and says `scope=block` covers one declaration. Applying `scope=file` clears the warning and leaves one edge | #76, PR #147 |
| F-XCUT-6 | fixed | The dotted path `policies.claims-write.per_minute` checks clean, and flipping 30 → 300 reports value drift. An ambiguous bare key gives GM360 "matches 2 keys ... write the dotted key path" | #77, PR #147 |
| F-XCUT-7 | fixed | Section 8: `gloss criticality: 0 suggestions` | #78, PR #147 |
| F-XCUT-8 | fixed | Section 9 prints the hint only under `exp:ClaimHistory`, which drift also lists as untested, and none under `exp:ClaimApproval` | #79, PR #147 |
| F-XCUT-9 | fixed | `variant-b` in a temp git repo: `impact --base HEAD` and `diff --base HEAD` both print `Concepts covered 50% → 50%   Files 75% → 75%` | #81, PR #140 |
| F-XCUT-10 | fixed | Section 10 no longer applies (`guards` is built-in). With an undeclared `shields`, check prints 2 errors, one per key | #82, PR #139 |

## deep-hierarchies

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-DEEP-1 | fixed | Repro: `spw:scanning now implements cyc:OrderFulfilment, which its manifest does not allow`, plus a gap for `cyc:ScanConfirm`. The committed catalogue has 0 violations | #83, PR #138 (cfa3b07) |
| F-DEEP-2 | fixed | After a rebuild the `cyc:HydraulicDiscBrake` node has `"kind":"entity","kind-from":"cyc:Product"`, the db boundary is consistent, and impact prints `cyc:Cassette (entity, core)` | #84, PR #138 |
| F-DEEP-3 | fixed | `cycles/` check: 8 errors. These are GM370 ×2, GM371 ×2, one boundary cycle, GM320 on WaveBuilder and BinRouter, and GM300 on the self-looped `cyc:Brake` | #85, PR #138 |
| F-DEEP-4 | fixed | After a rebuild, `spw:platform` is `"kind":"domain","dir":"platform","file":"platform/.gloss.yaml"`, and the Refund gap points at `[platform/.gloss.yaml:1]` | #86, PR #138 |
| F-DEEP-5 | fixed | Committed catalogue: `GM503 warnings: 0`. The mixed-chain copy has no GM503 on `spk:CsvRowParser` | #87, PR #149 (6f310d4) |
| F-DEEP-6 | fixed | Inherit repro: one finding naming `services/catalogue/ingest/feeds/.gloss.yaml` (plus one for ingest's own `IngestScheduler`). Fan-out: one finding `now implements spk:ScanVerifier (and through it ...)` | #88, PR #149 |
| F-DEEP-7 | fixed | After a rebuild, `via` runs to `spk:Importer`, the HydraulicDiscBrake node has `"criticality-source":"cyc:BrakingComponent"`, and the business fold of CatalogueIngestion includes `spk:ShimanoXmlImporter` | #89, PR #149 |
| F-DEEP-8 | fixed | `cyc:Accessory`/`cyc:Lighting` are no longer orphans. Without `produces`, the new orphans are Cassette, ElectronicFrontDerailleur and FrontDerailleur; FrontDerailleur's only descendant is the produced one, so the Done-when list was one short | #90, PR #149 |
| F-DEEP-9 | fixed | `(no unique subsumer: cyc:Derailleur, cyc:PoweredDevice)` is printed, and the `drivetrain` view has `spw:feeds produces` edges to Cassette, ElectronicFront- and ElectronicRearDerailleur | #91, PR #149 |
| F-DEEP-10 | fixed | `components: cyc:OrderFulfilment -> spw:fulfilment` | #92, PR #149 |
| F-DEEP-11 | fixed | `check --explain` for `spw:catalogue-db` takes 2 lines (`declared cyc:HydraulicDiscBrake, cyc:Product (+19 below)`), and GOVERNANCE.md says both tiers inherit | #93, PR #149 |

## monolith-decomposition

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-SPLIT-1 | fixed | Rebuilds of `during-split/invoicing-service` at two different paths are byte-identical, `grep -c '"/'` prints 0, and the file is `"../hirehq/ontology/hire.gloss.yaml"` | #94, PR #141 (448a437) |
| F-SPLIT-2 | fixed | `during/` drift prints two `overlap` lines (Invoicing, Invoice), and so does the landscape. With `deprecated`/`replaced-by`/`retire-by` there are none; with a past `retire-by`, `--fail-on overdue` exits 1 | #95, PR #148 (df93a1c) |
| F-SPLIT-3 | fixed | Without `tier:` check warns GM113, and FILE-FORMATS lists `tier` under imports. `gloss publish` writes `tier: implementation` and leaves out unpublished concepts, so a probe importing it gets GM215 rather than GM230 | #96, PR #141 |
| F-SPLIT-4 | fixed | `run.sh`: `gate HARD`, `[HARD: definition of a core concept changed (PATCH)]`, `Views changed: business, engineering`, exit=1 | #97, PR #148 |
| F-SPLIT-5 | fixed | Both diffs print a `Realization changes:` block with the expected lines, and during→after lists `invoicing-migration (removed)` | #98, PR #148 |
| F-SPLIT-6 | fixed | The retirement keys check clean (GM222 for the deprecated boundary). A misspelt `realises:` gives GM110 at line 8 ("the other keys still apply"), and the parent has 0 violations | #99, PR #139 |
| F-SPLIT-7 | fixed | View JSON: 1 node with `deprecated` and a `replaced-by` edge, panel keys include `deprecated`/`replacedBy`, and a rebuilt graph has 1 `replaced-by` edge (the committed graph has 0) | #100, PR #148 |
| F-SPLIT-8 | fixed | `inv:` under `prefixes:` with no import: check 0 errors (GM222 says "replacement ... unresolved here"). Renaming `InvoiceRun` in the service makes the landscape report a dangling `replaced-by` | #101, PR #148 |
| F-SPLIT-9 | fixed | `run.sh`: `Version hq: 1.0.0 → 1.0.0 (requires MINOR)` | #113, PR #148 |
| F-SPLIT-10 | fixed | Check warns GM611 for a future-dated `bogus:Nothing` ("matches no finding") and GM612 for the expired one; deadlines go in `retire-by` (`overdue`) | #102, PR #148 |
| F-SPLIT-11 | fixed | The header now reads `Context map (consumer → producer: depends on ...)`. The `part-of: bw:tool-hire` repro has no `bw:tool-hire →` edge. The payments example no longer exists upstream | #103, PR #141 |
| F-SPLIT-12 | fixed | Copy of `before/` plus five files: `diff` prints `Files 50% → 33%` | #104, PR #140 |
| F-SPLIT-13 | fixed | `run.sh`: `Retiring here: hq:InvoiceGenerator → inv:InvoiceRun (bw:invoicing-service). ...` | #105, PR #148 |

## version-evolution

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-VER-1 | fixed | Step 1a: `gate HARD`, the bump line is `[HARD: semver: bump the namespace version ...]`, exit 1. Step 3a's undersized MINOR is `[HARD]` | #106, PR #148 |
| F-VER-2 | fixed | `gloss lock` now pins to a vendored copy (`.glossmark/imports/`), and check says `2.0.0 available, outside ~1.0.0; still resolving the pinned 1.0.1` (GM116). An out-of-range `lock` exits 1 and leaves the lock unchanged (`--allow-out-of-range`) | #107, PR #141 |
| F-VER-3 | fixed | Step 1b: GM115 error. Step 1c: GM114 warning, and `diff` says `1.0.1 → none`, which is what importers see | #108, PR #141 |
| F-VER-4 | changed | Enforced only once a tier is known. Minimal repro (`ReadingFeed`→`ReadingIngestor` in outage-map) gives 0 errors and GM113 "GM230 is not enforced". With `tier: implementation` on the import, GM230 fires at `.gloss.yaml:1` and `omap.gloss.yaml:6` | via #96, PR #141 |
| F-VER-5 | fixed | Landscape has an `Imports` table (range, locked, resolved, status: `lock behind` / `out of range`), a `Deprecated in use` section with the four grid:Outage references, and an `Imports out of range` finding | #109, PR #148 |
| F-VER-6 | fixed | Step 5 drift lists 3 dangling references (manifest, ontology, marker). With `lock --update`, analytics' `allowed grid:Outage` is reported as a dangling manifest reference | #110, PR #148 |
| F-VER-7 | changed | The false gap is gone (ADR 0037: `holds` is declared ownership). With `lock --update` analytics resolves 2.0.0, and neither check nor drift says anything about `grid:Tariff` becoming a constraint | #111, PR #148 |
| F-VER-8 | fixed | Steps 3a/4: `concept grid:Outage removed (deprecated since base, replaced-by grid:SupplyInterruption)` | #112, PR #148 |
| F-VER-9 | fixed | Step 2a: `Version grid: 1.1.0 → 1.1.1 (requires MINOR) ✗` | #113, PR #148 |
| F-VER-10 | fixed | 40 `gloss lock` runs in outage-map all start with `gloss lock: grid:`, and the lock md5 is the same each time | #114, PR #141 |
| F-VER-11 | fixed | Step 5 landscape: `[outage-map/.gloss.yaml:1]`, `[meter-core/ontology/grid.gloss.yaml:14]` | #115, PR #148 |

## FINDINGS-ADOPTION

| Finding | Status | Evidence (one line) | Upstream |
| --- | --- | --- | --- |
| F-ADOPT-1 | fixed | `init --dry-run` on stripped clinic-booking plans `apps/web`, `services/booking-api`, `services/reminders`, `deploy`, `db` and `infra`; `--boundary-prefix` exists and the guessed prefixes are flagged | #35, PR #146 (aeba4db); #229, PR #255 |
| F-ADOPT-2 | fixed | Scratch git repo with `.github/` at the root: doctor in `showcase/clinic-booking` gives `✓ CI pins: ... ../../.github/workflows/showcase.yml`, and init in a subdirectory skips `.github/workflows/gloss.yml` and prints the job | #36, PR #146 |
| F-ADOPT-3 | fixed | With a fake `gloss` first on PATH, doctor reports `✗ gloss on PATH: ... is not GlossMark`. hook install points the local hook at the absolute path | #37, PR #142; #226, PR #255 |
| F-ADOPT-4 | fixed | FILE-FORMATS' derived set lists `holds`, `presents`, `hosts` and `configures`; ADVANCED.md has the `--fail-on` kinds; GOVERNANCE.md says value drift changes no view | #38, PR #137; #161, PR #163 (86fe157) |
| F-ADOPT-5 | fixed | Stripped clinic-na: text and JSON both give 35 proposals (71/71 at `--min-conf 0.05`). Upstream could not reproduce it at v0.1.0 either | #39 (closed, not planned) |
| F-ADOPT-6 | fixed | With `realizes:` removed from `apps/web/.gloss.yaml`, there is one violation at `clinicb:web`, pointing at `[apps/web/.gloss.yaml:1]` | #40, PR #146 |
| F-ADOPT-7 | fixed | `lark:LeadTimeSetting` in reminders' `realizes`: Gaps 0. A two-entry `value-from` on CancellationPolicy reports drift when either the Go or the TS location changes (see R4) | #41, PR #146 |
| F-ADOPT-8 | fixed | After `accept --all`, Stale is 0. After a real edit, `gloss accept <id>` re-confirms the link, and Stale is 0 again | #42, PR #142 |
| F-ADOPT-9 | fixed | clinic-booking: `gloss criticality: 0 suggestions` | #43, PR #146 |
| F-ADOPT-10 | fixed | The SQLite export lists `db/migrations/0006_roles.sql` (and 0005) as `node='file'` with `criticality='high'` | #44, PR #146 |
| F-ADOPT-11 | fixed | `drift --fail-on bogus` and `landscape --fail-on bogus` exit 2 and print the valid kinds | #45, PR #140 |
| F-ADOPT-12 | not re-checkable | Needs a live PR that touches two workspaces. Code read only: `action.yml` at 0be26e3 sets the marker to ``<!-- glossmark-impact:${root} -->``, keeps the legacy marker for `root: .`, and `showcase.yml` pins 0be26e3 | #46, PR #140 |

## New rough edges

**R1. landscape: a sibling pinned to an older version hides another importer's dangling references** (GlossMark #287). `gloss landscape` merges the graphs by IRI. When one importer is pinned to an older version of a namespace, that version's concept nodes come into the union, and they resolve references that are dangling for an importer on the newer version. Repro: `lab/version-evolution` through step 4 with `gloss lock --update`, so that analytics resolves grid 2.0.0 (no `grid:Outage`) and outage-map stays pinned at 1.2.0. `gloss landscape meter-core analytics` prints `! Dangling references` for `analytics/.gloss.yaml:1 allowed grid:Outage` and `analytics/models/outage_minutes.sql:1`, then exits 1. `gloss landscape meter-core billing outage-map analytics` prints neither and exits 0. Proposed: resolve each repository's references against the version that repository resolves, or report a namespace resolved at several versions. Done when: the four-repository landscape reports both analytics references and exits 1.

**R2. suggest drops candidates outside the derived allowed set without saying so, so an init-scaffolded workspace gets no core proposals.** `gloss init` writes manifests that set only `default-namespace: <ns>i`, so the derived allowed set is the implementation namespace. ADR 0022 makes suggest test every candidate against that set. An adopter who writes the core tier first (adopt-glossmark step 3) therefore gets 0 proposals. The only message is about the empty implementation tier, and nothing says how many candidates were dropped. Repro: in a copy of `showcase/clinic-booking` without GlossMark files, run `gloss init --no-hook` and write three core concepts (`Booking`, `Appointment`, `Practitioner`). `gloss suggest --format json` then gives `0` proposals. Appending `allowed: [derived, a1:Booking, a1:Appointment, a1:Practitioner]` to each manifest gives 5. Proposed: count the candidates dropped by the allowed set in the summary line (`... 5 outside the allowed set; declare them under realizes: or holds:`), or propose them as HARD with the reason. Done when: the first run names the 5 dropped candidates.

**R3. The "0 concepts defined" hint fires in a workspace that only imports its vocabulary.** analytics owns no namespace and links three imported `grid:` concepts. `gloss check` prints `gloss check: 0 concepts defined. Draft some with gloss suggest --concepts`. `gloss drift` prints `No concepts are defined yet, so there is nothing to compare`, even in the same output where it reports 2 dangling references and exits 1. Both lines come after the summary line, which also breaks `| tail -1` scripts (see Lab maintenance). Repro: `cd lab/version-evolution/analytics && $GLOSS check` (copy), or the step 4 transcript with `lock --update`. Proposed: count imported concepts, and give the hint only when neither owned nor imported concepts exist. Done when: analytics' check and drift print no hint.

**R4. A second `value-from` location reports value drift before any code changes.** The value baseline is one joined string. When a second location is added to `value-from`, the next drift reports `which changed from "const CancellationWindow = 24 * time.Hour" to "const CANCELLATION_WINDOW_HOURS = 24; | const CancellationWindow = 24 * time.Hour"`, which reads as a code change, until `gloss accept --value` is run. Repro: copy `showcase/clinic-booking`, then change `lark:CancellationPolicy`'s `value-from` to a list that adds `{ path: "apps/web/app/appointments/[id]/page.tsx", symbol: CANCELLATION_WINDOW_HOURS }`, then build and drift. Proposed: keep one baseline per location, and record a new location's baseline when it is added. Done when: adding the second location reports no value drift.

**R5. `suggest --concepts` merges a whole god-table codebase into one cluster named after a stray word.** On the stripped `lab/concept-poor-legacy/opstool` with empty `wh:`/`ops:` tiers, `gloss suggest --concepts` prints one candidate, `wh:NEW:Back`, with 22 members: every `Manager`, `Processor` and helper method and all nine tables. Its words are `back, what, ord, anyth, bin, cart`. The shared `tbl_data` links everything. Proposed: ignore tables touched by more than a set share of declarations when clustering, and drop non-domain words (`what`, `anyth`) from names. Done when: a cluster holding `Processor`, `tbl_rma` and `tbl_rma_vendor` and not `Manager` appears (F-POOR-7's Done-when).

**R6. The landscape context map lists a producer and its enclosing system as two edges.** `lab/monolith-decomposition/during-split`: `gloss landscape --repo hirehq --repo invoicing-service` prints both `bw:invoicing-service → bw:hirehq via hire:Hire` and `bw:invoicing-service → bw:tool-hire via hire:Hire`, and `bw:tool-hire` is the system that contains `bw:hirehq`. Proposed: keep only the deepest producing boundary per consumer and concept. Done when: only the `bw:hirehq` edge is printed.

## Lab maintenance

- Six `run.sh` default `GLOSS` to `/home/ckessler/dev/glossmark-examples/.tools/bin/gloss`: ambiguous-surfaces, concept-poor-legacy, confidence-calibration, cross-cutting-concerns, deep-hierarchies and version-evolution. monolith-decomposition uses `$ROOT/.tools/bin/gloss`; use that everywhere.
- Every FINDINGS.md says v0.1.0, and none says the finding is closed. Link this file, or add a status line per finding.
- The committed `.glossmark/` graphs and ledgers predate the current binary, and several scripts read them without rebuilding:
  - ambiguous-surfaces `measure.py`: the "surface boundary" column is stale in 7 rows (for example `bff/b-presents` shows `critical`, but `none` after a rebuild).
  - deep-hierarchies: the criticality/kind section, the `via` section and the F-DEEP-4 `grep` show the old bugs.
  - monolith `during-split/invoicing-service`: the graph still holds `/home/ckessler/...` paths, and `during/` has 0 `replaced-by` edges.
  - cross-cutting-concerns: the legacy ledgers have no decorator fingerprints, so section 1 shows `Stale: 0` where a fresh ledger gives stale links. Deleting one marker line on a legacy-ledger file reports one spurious stale link.

  Run `gloss build` in every workspace and commit the result.
- Output format changes break the scripts' text matching:
  - The drift trailer now ends with a `What these mean: ...` line, so `drift | tail -1` misses the summary (concept-poor A/B/C).
  - `impact --base | tail -1` picks up `Criticality touched` (cross-cutting section 11).
  - The drift trailer no longer has `Files` (monolith F-SPLIT-12 section is empty).
  - The wording changed from `is implemented but`, `but declares`, `orphan concept` and `(, `, so cross-cutting section 3 and the deep-hierarchies F-DEEP-6, F-DEEP-8, explain and impact sections print nothing.
- `suggest --format json` is now an object `{auto_accept, proposals}`. This breaks concept-poor `score.py` and its `jq '.[]'` calls, and confidence-calibration section 3. Some `gloss diff --format json` changes have no `symbol` (calibration section 4 `KeyError`).
- concept-poor `pristine()` strips manifest intents but keeps `default-namespace: ops`. suggest's allowed-set filter (R2) then drops every core candidate, and the F-POOR-1/2/3 tables show 0 proposals. The evidence above comes from a scratch copy that appends `allowed: [derived, <every wh: concept>]` to each manifest. The F-POOR-5 section selects a proposal suggest no longer makes, so it runs `reject` on an empty id.
- confidence-calibration: all four `data/*-suggest*.json` differ from the regenerated batches (35/35/22/21 proposals against 111/126/37/46). `labels.csv` and the section 6 tables describe v0.1.0, so F-CAL-1 and F-CAL-5 need a new labelling pass.
- cross-cutting section 10 can no longer fail, because `guards` is built in. Use an undeclared name such as `shields`.
- version-evolution:
  - `TRANSCRIPT.md` matches `e24677c` byte for byte and differs from 0be26e3 in 172 lines. The changes are the drift footer, 12 `0 concepts defined` lines (R3), the analytics `holds grid:Outage` violation gone, and `mc:ReadingFeed` untested.
  - `lock_importer` runs `gloss lock`, which pins, so no importer moves past grid 1.0.1. Steps 2 to 4 never exercise the new versions downstream, and step 5's `gloss lock` exits 1. Use `gloss lock --update` (that variant is how F-VER-6/7 and R1 were checked).
  - run.sh bumps the ontology file but never `owns.grid.version` in `meter-core/glossmark.yaml`, so meter-core fails GM115 from step 1.
  - outage-map imports `mc:` without `tier:`, which raises GM113 on every check and keeps F-VER-4's rule off.
- monolith-decomposition:
  - The F-SPLIT-11 section looks for `../GlossMark/examples/payments`, which upstream no longer has (only `examples/library`).
  - `during-split/hirehq/ontology/inv.gloss.yaml` draws GM402 (own-subject rule) on every check (already with `e24677c`).
