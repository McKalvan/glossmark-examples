# Findings: ambiguous surfaces

All output below comes from the v0.1.0 release binary (`$GLOSS`). `run.sh` reproduces every table; repros that need an edit work on a temporary copy.

## Verdict

**Partly.** GlossMark v0.1.0 gives an adopter enough relations to mark every one of the six surfaces truthfully, and `presented-only` does exactly what the ADR promises. But the choice of relation moves four signals in ways the docs do not predict, and in two places the tools disagree with each other about the same file. Item by item against [HYPOTHESIS.md](HYPOTHESIS.md):

| # | Expectation | Result | Evidence |
| --- | --- | --- | --- |
| H1 | A surface keeps a test obligation | **No** for inline `presents`, **yes** for a page concept | `server-page/b-presents`: no `untested`, coverage 0/0. `server-page/d-page-concept`: `untested: hpx:QuotePage`. F-SURF-9 |
| H2 | A file that changes a critical value is critical, without claiming it implements the rule | **Partly** | `configures` gives `critical` in the graph and in `impact` and keeps placement, but cannot be declared in a manifest (F-SURF-5). Inline `presents` gives `none` in the graph and `critical` in `impact` and `diff` (F-SURF-1). A page concept with a declared level works (`admin-limit/e-page-concept-critical`) |
| H3 | `presents` and `implements` on one declaration | **Yes** | `server-page/c-both`, `cli/c-both`: no lint, `presented-only` clears, the file takes the implemented concept's level |
| H4 | Surfaces never move a concept out of its engine's box | **No** | `presents` and `hosts` never do. `implements` on the surface does, and where it moves to depends on whether the link is direct or through an implementation concept (F-SURF-2) |
| H5 | `presented-only` means "no mechanism" | **Yes** | Fires in `server-page/b-presents` and `cli/b-presents`; silent in `pdf-invoice/a-presents-entity`, where a model `represents hp:Invoice` |
| H6 | Wrong relations are caught | **No** | `cli/e-hosts-only`: a critical process with no mechanism, `hosts` as its only marker, 0 warnings and 0 findings (F-SURF-4) |
| H7 | API schema types do not become storage | **No** | `graphql/d-schema-represents`: the gateway derives `holds hp:Order` and the entity moves to the root box (F-SURF-8) |
| H8 | The reports agree | **No** | `export --status` says `implemented` for a hosted-only concept with no finding at all (F-SURF-4), and `impact` disagrees with the graph on criticality (F-SURF-1) |
| added | Drift catches a surface that implements | **No** | A manifest that declares only `presents` (even with `realizes: []`) is never violated by code that `implements` (F-SURF-3). The opposite mistake gives the gap ADR 0001 promises |
| H9 | The choice is visible | **Yes** | Every case has variants that differ in at least two of the four signals (tables below) |

**What worked well.** `presented-only` is precise: it fired on the two surfaces with no mechanism and on nothing else, and it understands that an entity is satisfied by `represents`. Two markers with different relations on one declaration are accepted without complaint and both edges land on the same artifact. `scope=block` inside a Django view anchors the discount `if` and its body only (lines 32 to 33 of `server-page/e-split-block/storefront/quotes/views.py`, inside the view's symbol anchor at 15 to 45), so a surface can say exactly which lines are the mechanism. An Express `router.get(...)` call anchors as a block with a sensible signature. The GM503 warning on `bff/a-implements` (the BFF's test verifies the credit rule its manifest does not claim) is a real signal that the surface duplicates a rule. `produces` on the PDF renderer is a clean answer for "the output is the product": critical in the graph and in `impact`, placement kept, no lint.

## Results

One row per variant, from `./run.sh`. **Coverage** is `gloss coverage`'s concept headline. **Surface criticality** is the level on the surface file's artifact node in `.glossmark/graph.jsonl` (what the viewer, the SQLite export and the governance query see), then the level `gloss impact <file>` reports. **Placement** is each core concept's `boundary` in the engineering view of `gloss view --json`; `-` means no box. The business view zooms to `system`, so every concept there sits in the root box `hpb:harbor` or in none; it cannot show these differences. No variant shows a violation because each manifest declares what its own markers derive; F-SURF-3 shows what happens when the manifest and the markers disagree.

### admin-limit

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| admin-limit/a-presents | 0e/0w | none | 1/1 | `CreditLimitPage.tsx` graph none, impact critical | hpb:admin critical | hp:CreditLimit→hpb:orders |
| admin-limit/b-implements | 0e/0w | none | 1/1 | `CreditLimitPage.tsx` graph critical, impact critical | hpb:admin critical | hp:CreditLimit→hpb:admin |
| admin-limit/c-configures | 0e/2w GM503 | none | 1/1 | `CreditLimitPage.tsx` graph critical, impact critical | hpb:admin critical | hp:CreditLimit→hpb:orders |
| admin-limit/d-page-concept | 0e/0w | none | 2/2 | `CreditLimitPage.tsx` graph none, impact none | hpb:admin critical | hp:CreditLimit→hpb:orders |
| admin-limit/e-page-concept-critical | 0e/0w | none | 2/2 | `CreditLimitPage.tsx` graph critical, impact critical | hpb:admin critical | hp:CreditLimit→hpb:orders |

### server-page

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| server-page/a-implements | 0e/0w | none | 0/0 | `views.py` graph high, impact high | hpb:storefront high | hp:Pricing→hpb:storefront |
| server-page/b-presents | 0e/0w | presented-only: hp:Pricing | 0/0 | `views.py` graph none, impact high | hpb:storefront none | hp:Pricing→- |
| server-page/c-both | 0e/0w | none | 0/0 | `views.py` graph high, impact high | hpb:storefront high | hp:Pricing→hpb:storefront |
| server-page/d-page-concept | 0e/0w | presented-only: hp:Pricing; untested: hpx:QuotePage | 0/1 | `views.py` graph none, impact none | hpb:storefront none | hp:Pricing→- |
| server-page/e-split-block | 0e/0w | presented-only: hp:Pricing; untested: hp:VolumeDiscount | 0/0 | `views.py` graph high/none, impact high | hpb:storefront high | hp:Pricing→-, hp:VolumeDiscount→hpb:storefront |

### cli

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| cli/a-implements | 0e/0w | none | 0/0 | `close_period.py` graph critical, impact critical; `cli.py` graph unmarked, impact none | hpb:hpctl critical | hp:PeriodClose→hpb:hpctl |
| cli/b-presents | 0e/0w | presented-only: hp:PeriodClose | 0/0 | `close_period.py` graph none, impact critical; `cli.py` graph unmarked, impact none | hpb:hpctl none | hp:PeriodClose→- |
| cli/c-both | 0e/0w | none | 0/0 | `close_period.py` graph critical, impact critical; `cli.py` graph unmarked, impact none | hpb:hpctl critical | hp:PeriodClose→hpb:hpctl |
| cli/d-hosts-group | 0e/0w | none | 0/0 | `close_period.py` graph critical, impact critical; `cli.py` graph none, impact critical | hpb:hpctl critical | hp:PeriodClose→hpb:hpctl |
| cli/e-hosts-only | 0e/0w | none | 0/0 | `close_period.py` graph none, impact critical; `cli.py` graph unmarked, impact none | hpb:hpctl none | hp:PeriodClose→- |

### bff

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| bff/a-implements | 0e/1w GM503 | none | 2/2 | `reorder.ts` graph high, impact high | hpb:mobile-bff high | hp:CreditLimit→hpb:orders, hp:OrderPlacement→hpb:mobile-bff |
| bff/b-presents | 0e/1w GM503 | none | 2/2 | `reorder.ts` graph none, impact high | hpb:mobile-bff critical | hp:CreditLimit→hpb:orders, hp:OrderPlacement→hpb:orders |
| bff/c-hosts | 0e/1w GM503 | none | 2/2 | `reorder.ts` graph none, impact high | hpb:mobile-bff critical | hp:CreditLimit→hpb:orders, hp:OrderPlacement→hpb:orders |
| bff/d-split | 0e/0w | none | 2/2 | `reorder.ts` graph critical/none, impact critical | hpb:mobile-bff critical | hp:CreditLimit→hpb:mobile-bff, hp:OrderPlacement→hpb:orders |
| bff/e-impl-bff | 0e/1w GM503 | none | 3/3 | `reorder.ts` graph high, impact high | hpb:mobile-bff high | hp:CreditLimit→hpb:orders, hp:OrderPlacement→hpb:harbor |

### graphql

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| graphql/a-implements | 0e/0w | none | 2/2 | `resolvers.ts` graph high, impact high; `server.ts` graph unmarked, impact none; `schema.graphql` graph unmarked, impact none | hpb:gateway high | hp:CreditLimit→hpb:orders, hp:Order→hpb:orders, hp:OrderPlacement→hpb:gateway |
| graphql/b-presents | 0e/0w | none | 2/2 | `resolvers.ts` graph none, impact high; `server.ts` graph unmarked, impact none; `schema.graphql` graph unmarked, impact none | hpb:gateway critical | hp:CreditLimit→hpb:orders, hp:Order→hpb:orders, hp:OrderPlacement→hpb:orders |
| graphql/c-hosts-server | 0e/0w | none | 2/2 | `resolvers.ts` graph none, impact high; `server.ts` graph none, impact high; `schema.graphql` graph unmarked, impact none | hpb:gateway critical | hp:CreditLimit→hpb:orders, hp:Order→hpb:orders, hp:OrderPlacement→hpb:orders |
| graphql/d-schema-represents | 0e/1w GM503 | none | 2/2 | `resolvers.ts` graph none, impact high; `server.ts` graph unmarked, impact none; `schema.graphql` graph high, impact high | hpb:gateway high | hp:CreditLimit→hpb:orders, hp:Order→hpb:harbor, hp:OrderPlacement→hpb:orders |

### pdf-invoice

| variant | check | drift (violation, gap, presented-only, untested, orphan) | coverage | surface criticality | surface boundary | placement (engineering view) |
| --- | --- | --- | --- | --- | --- | --- |
| pdf-invoice/a-presents-entity | 0e/0w | none | 1/1 | `invoice_pdf.py` graph none, impact critical | hpb:documents critical | hp:Invoice→hpb:billing, hp:Invoicing→hpb:billing |
| pdf-invoice/b-presents-process | 0e/1w GM503 | none | 1/1 | `invoice_pdf.py` graph none, impact critical | hpb:documents critical | hp:Invoice→hpb:billing, hp:Invoicing→hpb:billing |
| pdf-invoice/c-implements | 0e/1w GM503 | none | 2/2 | `invoice_pdf.py` graph critical, impact critical | hpb:documents critical | hp:Invoice→hpb:billing, hp:Invoicing→hpb:harbor |
| pdf-invoice/d-produces | 0e/0w | none | 1/1 | `invoice_pdf.py` graph critical, impact critical | hpb:documents critical | hp:Invoice→hpb:billing, hp:Invoicing→hpb:billing |
| pdf-invoice/e-represents | 0e/0w | none | 1/1 | `invoice_pdf.py` graph critical, impact critical | hpb:documents critical | hp:Invoice→hpb:harbor, hp:Invoicing→hpb:billing |

What the tables say, case by case:

- **admin-limit.** Only `configures` and a page concept with a declared level make the page critical everywhere while keeping `hp:CreditLimit` in the order service's box. `implements` makes it critical, but draws the credit limit inside the admin console. Inline `presents` and an undeclared page concept leave the graph at `none`.
- **server-page.** When the view is the only place the price is computed, `presents` alone produces `presented-only` and drops the file and the boundary to `none`. `implements`, alone or with `presents`, is the only marking that keeps `high`. The split (`presents` on the view, `implements` on the discount block) is the most precise, and it still reports `hp:Pricing` as presented-only, which is true: nothing names the price computation itself.
- **cli.** Same as the server page. `hosts` on the command (`e-hosts-only`) is the worst choice and the only one with no finding at all.
- **bff.** `presents` and `hosts` give identical results. `implements` moves `hp:OrderPlacement` into the BFF's box; the implementation-concept form (`e-impl-bff`) moves it to the root. The split moves the critical `hp:CreditLimit` into the BFF's box. The BFF boundary is `critical` when it only presents and `high` when it implements (F-SURF-10).
- **graphql.** Like the BFF. `represents` on a schema type moves `hp:Order` to the root.
- **pdf-invoice.** `presents` of the entity or of the process loses criticality in the graph. `implements` through a concept moves `hp:Invoicing` to the root and hides that the renderer has no test of its own (F-SURF-6). `represents` moves `hp:Invoice` to the root. `produces` keeps everything.

## Decision rule

For a new user, in order. Stop at the first rule that applies, then apply rule 6 to every surface.

1. **Delete-test the file.** If deleting it would stop a business rule from being enforced or a number from being computed anywhere, the file is a mechanism. Mark the declaration that does it `implements` (narrowest declaration, or `scope=block` for inline code), even if the file is also a page or a command. Add `presents` on the same declaration only if it also shows the concept to a user. *Server-rendered pricing, CLI commands, a BFF that re-applies a rule.* Expect the concept to move into this boundary's box, or to the root when an engine elsewhere also implements it (F-SURF-2).
2. **It changes a constraint's or measure's value at runtime** (an admin form, a settings page, a feature-flag console): mark it `configures` the constraint. Add `allowed: [derived, hp:X]` to the manifest, because `configures:` is not a manifest key (F-SURF-5). Do not use `presents`: the graph will rate the file `none`.
3. **Its output is the product** (an invoice PDF, a statement, a regulatory file): mark it `produces` the entity, and declare `produces:` on its manifest. Not `represents`, which makes the boundary hold the entity and moves the entity to the root box.
4. **It only shows or reshapes** what a mechanism elsewhere computes (a page, a GraphQL resolver, a BFF route without rules): `presents`. When the surface has tests or logic of its own, model it as an implementation concept with `presents:` in the ontology and `implements .ThatPage` on the code, so `untested` and coverage see it (F-SURF-9). Leave API schema types unmarked, or mark them `presents`.
5. **`hosts`** is only for a shell that routes to several surfaces: the app frame, the CLI group, the GraphQL server. Target a system-type or the page concepts it hosts. Never make `hosts` the only marker on a process, capability or constraint: it silences `presented-only` and drops criticality (F-SURF-4).
6. **Check the four signals after marking.** Run `gloss drift` (a `presented-only` means rule 1 was skipped), `gloss impact <file>` and the artifact's `criticality` in `graph.jsonl` (they can disagree, F-SURF-1), and the engineering view's placement. Do not rely on the manifest to catch a surface that implements: a `presents`-only manifest never produces a violation (F-SURF-3).

## F-SURF-1: impact and diff rate a presented file at the concept's level; the graph rates it none

**Problem.** ADR 0001 rule 3 and GOVERNANCE.md say an artifact takes no level from a concept it `presents` or `hosts`. The graph follows that rule. `gloss impact` and `gloss diff` do not: they rate the same file at the presented concept's level and gate it HARD under `criticality-gates`. So the PR gate treats the admin page that edits the credit limit as critical, while the viewer, `export --sqlite` and the governance query GOVERNANCE.md recommends treat it as unclassified. A reviewer cannot tell which answer is the rule. The same split appears for every presents-only and hosts-only surface in this lab: 12 of the 29 variants in the tables show `graph none, impact <level>`.

**Repro.** `lab/ambiguous-surfaces/admin-limit/a-presents`:
```sh
$ grep CreditLimitPage.tsx .glossmark/graph.jsonl | grep '"node":"artifact"' | jq -c '{path, criticality}'
{"path":"apps/admin/src/pages/CreditLimitPage.tsx","criticality":null}
$ $GLOSS impact apps/admin/src/pages/CreditLimitPage.tsx
apps/admin/src/pages/CreditLimitPage.tsx  [HARD, hpb:admin, criticality critical]
  ...
  → criticality critical (via hp:CreditLimit): a reviewer who owns this area should see the change
$ $GLOSS export --sqlite /tmp/a.db && sqlite3 /tmp/a.db "SELECT path, criticality FROM nodes WHERE node='artifact' AND criticality IN ('high','critical')"
apps/admin/tests/CreditLimitPage.test.tsx|critical
services/orders/credit.go|critical
services/orders/credit_test.go|critical
```
The governance query lists the page's test, but not the page. With `policy: { criticality-gates: { critical: HARD } }` added and the marker added in a temporary git repository, `gloss diff --base HEAD` prints:
```
+ presents hp:CreditLimit   apps/admin/src/pages/CreditLimitPage.tsx:CreditLimitPage   [CRITICAL, agent, HARD: existing concept, valid, inside allowed; criticality critical: hp:CreditLimit]
```

**Proposed change.** One rule in every consumer. Keep ADR 0001 for the stamped level (criticality follows the mechanism), and make `impact` and `diff` say what is true instead of borrowing the level: `presents hp:CreditLimit (critical): this file shows a critical concept; it is not rated by it`. Combine with F-SURF-4's lint so a `presents` on a constraint is steered to `configures`, which does carry the level (F-SURF-5). If the project prefers the gate's behaviour, change the graph instead and amend the ADR; either way, both must agree.

**Done when.** On `admin-limit/a-presents`, the artifact node's `criticality` and the level in `gloss impact`'s header line are the same value.

## F-SURF-2: a surface that implements a concept steals its placement, depending on marking style

**Problem.** FILE-FORMATS.md places a concept in the boundary "whose own code links to the concept directly", ahead of one that "reaches it by lifting through another concept". Engines are normally marked through an implementation concept (`implements .CreditCheck`, which realizes `hp:CreditLimit`). A surface that adds a direct `implements hp:X` therefore outranks the engine, and the viewer draws the core concept inside the BFF, the admin console or the GraphQL gateway. If the surface uses an implementation concept instead, both boundaries lift and the concept moves to the root. Placement depends on whether someone wrote a core CURIE or an implementation CURIE, not on what the code does. `presents` and `hosts` never move placement (ADR rule 6 holds).

**Repro.** Engineering view, `jq -r '.views[] | select(.name=="engineering") | .nodes[] | select(.tier=="core") | "\(.id) \(.boundary)"'` after `$GLOSS view --json -o /tmp/v.json`:
```
bff/a-implements:         hp:CreditLimit hpb:orders; hp:OrderPlacement hpb:mobile-bff
bff/b-presents:           hp:CreditLimit hpb:orders; hp:OrderPlacement hpb:orders
bff/e-impl-bff:           hp:CreditLimit hpb:orders; hp:OrderPlacement hpb:harbor
admin-limit/b-implements: hp:CreditLimit hpb:admin
```
The code in the four workspaces is identical apart from `@gloss` lines (`run.sh` checks this). In `admin-limit/b-implements` the credit limit, whose only enforcement is `services/orders/credit.go`, is drawn inside the admin console.

**Proposed change.** Treat "its own code implements an implementation concept that realizes X" as the same strength as a direct link: one realizes hop through a concept implemented in that boundary is the boundary's own code. Then two mechanisms always resolve to the nearest common box, whichever CURIE style each used. Optionally, prefer a boundary whose manifest declares the concept (or the implementation concept realizing it) over one that only derives it.

**Done when.** `bff/a-implements` and `bff/e-impl-bff` place `hp:OrderPlacement` in the same box, and `admin-limit/b-implements` does not place `hp:CreditLimit` in `hpb:admin`.

## F-SURF-3: a manifest cannot say "this boundary is only a surface"

**Problem.** The manifest is where an architect states what a boundary is for, and `drift` is what catches code that exceeds it. For surfaces that only works one way. A boundary that declares `realizes: [hp:X]` while its code only presents X gets a gap, the reminder ADR 0001 promises. The reverse, the mistake this experiment is about, is invisible: a boundary declared as a surface (`presents: [hp:X]`, no `realizes`) whose code `implements` X gets no violation, because an undeclared relation is not compared, and an explicit `realizes: []` is treated the same as no key. The only finding is a gap on `presents` whose text says "intended capability not implemented". This is why every committed variant above shows no violation: each manifest matches its own markers, and no manifest can forbid a relation.

**Repro.** Copy `lab/ambiguous-surfaces/server-page/a-implements` (the view `implements hp:Pricing`), replace `realizes: [hp:Pricing]` with `presents: [hp:Pricing]` in `storefront/.gloss.yaml`, append `realizes: []`, rebuild:
```
$ $GLOSS drift --fail-on none
Ontology drift
○ Gaps (declared, not implemented)
  hpb:storefront declares presents hp:Pricing but nothing under it presents it: intended capability not implemented, or the declaration is wrong  [storefront/.gloss.yaml:1]
Concepts covered 0% (0/0 with an artifact and a verifier)   Files 67% (2/3)   Orphans: 0   Rogue: 0   Violations: 0   Gaps: 1   ...
```
The other direction, on a copy of `server-page/b-presents` with `presents:` replaced by `realizes: [hp:Pricing]`:
```
  hpb:storefront declares realizes hp:Pricing but nothing under it implements it: intended capability not implemented, or the declaration is wrong  [storefront/.gloss.yaml:1]
```

**Proposed change.** Compare an explicitly written empty list: `realizes: []` means "this boundary realizes nothing", and any derived `realizes` is a violation. Word the `presents`/`hosts` gap for what it is ("declares presents hp:Pricing but nothing under it presents it; its code implements it instead") when the concept is reached through another relation.

**Done when.** The first repro reports `violation: hpb:storefront realizes hp:Pricing, declared realizes []`.

## F-SURF-4: hosts hides a missing mechanism, with no lint and no finding

**Problem.** ADR 0001 rule 4 exempts `hosts` from `presented-only` "because a shell hosting a whole system-type is expected to have no single implementation". Nothing checks that the hosted concept is a system-type. Marking a critical process `hosts` (a plausible reading for a CLI command, a router or a GraphQL server) gives a concept with no mechanism, no finding in `drift`, no warning in `check`, `implemented` in `export --status`, and a file rated `none` in the graph.

**Repro.** `lab/ambiguous-surfaces/cli/e-hosts-only`. `tools/hpctl/hpctl/close_period.py` does the whole period close; its only marker is `# @gloss hosts hp:PeriodClose`, and `hp:PeriodClose` is `critical`.
```
$ $GLOSS check
gloss check: 0 errors, 0 warnings
$ $GLOSS drift --fail-on none
Ontology drift

Concepts covered 0% (0/0 with an artifact and a verifier)   ...   Violations: 0   Gaps: 0   Stale: 0   Untested: 0   ...
$ $GLOSS export --status /dev/stdout
[ { "concept": "hp:PeriodClose", "tier": "core", "kind": "process", "status": "implemented", "artifacts": 1, "verifiers": 1, ... } ]
```
The same file marked `presents` (`cli/b-presents`) reports `presented-only: hp:PeriodClose`.

**Proposed change.** Two parts. (1) A `gloss check` warning when `hosts` targets anything other than a `system-type` or an implementation concept that itself `presents` or `hosts` (a page), and when `presents` targets a `constraint` (suggest `configures`, F-SURF-5). (2) Extend `presented-only` to hosted concepts that are not system-types, or add a `hosted-only` kind, and make `export --status` report `presented-only`/`hosted-only` as the status instead of `implemented`.

**Done when.** `cli/e-hosts-only` prints a check warning on line 10 of `close_period.py` and a drift finding for `hp:PeriodClose`, and `export --status` does not say `implemented`.

## F-SURF-5: configures, the right relation for a value editor, is second-class

**Problem.** An admin page that edits a constraint's value is neither the mechanism nor only a view. `configures` says exactly that. Of the relations tried, it is the only one that keeps the constraint in its engine's box while giving the page the constraint's level everywhere (graph, `impact`, `diff`); `implements` also gives the level but moves the box (F-SURF-2). But a manifest cannot declare it (GM110), so the page's link and the page's test are both outside the derived allowed set (GM503, HARD in the gate), and on a constraint it lifts nothing to the boundary, so `drift` never compares it. The only fix is `allowed: [derived, hp:CreditLimit]`, which turns off the check rather than stating the intent. Related to F-ADOPT-7, which covers `publishes-value`; here the value lives in a database row, so neither `value-from` nor `publishes-value` applies.

**Repro.** `lab/ambiguous-surfaces/admin-limit/c-configures`:
```
$ $GLOSS check
apps/admin/src/pages/CreditLimitPage.tsx:7: warning: configures hp:CreditLimit is outside the allowed set derived from apps/admin/.gloss.yaml (HARD gate); declare the concept there, or write allowed: to widen it ... [GM503]
apps/admin/tests/CreditLimitPage.test.tsx:7: warning: verifies hp:CreditLimit is outside the allowed set derived from apps/admin/.gloss.yaml (HARD gate); ... [GM503]
gloss check: 0 errors, 2 warnings
```
Following the message's advice on a copy (`echo 'configures: [hp:CreditLimit]' >> apps/admin/.gloss.yaml`):
```
apps/admin/.gloss.yaml:1: error: apps/admin/.gloss.yaml: yaml: unmarshal errors:
  line 6: field configures not found in type model.Manifest [GM110]
```
`allowed: [derived, hp:CreditLimit]` instead checks clean; the graph then has one `configures` edge, from the artifact, and none from `hpb:admin`.

**Proposed change.** Accept `configures:` in manifests, add it to the derived allowed set, lift `configures` on any concept kind to the boundary as itself (as `presents` and `hosts` do), and compare it in `drift`. Document it in MARKING.md as the relation for "edits this concept's value at runtime".

**Done when.** `admin-limit/c-configures` with `configures: [hp:CreditLimit]` in `apps/admin/.gloss.yaml` checks with 0 warnings, and the graph has a `hpb:admin configures hp:CreditLimit` edge.

## F-SURF-6: an implementing surface is credited with the engine's tests

**Problem.** The ADR's motivation was that `untested` "cannot say the engine is tested and the page is not". That is fixed for `presents`, but when a surface `implements` an implementation concept, `untested` and coverage count it as verified if any test anywhere verifies the core concept it realizes. The PDF renderer below has no test; the billing engine's test of `hp:Invoicing` makes it covered. `gloss impact` gets it right.

**Repro.** Copy `lab/ambiguous-surfaces/pdf-invoice/c-implements`, delete the `@gloss verifies` line from `services/documents/tests/test_invoice_pdf.py`, and rebuild:
```
$ $GLOSS coverage | head -1
concepts 100.0% (2 of 2 implementation concepts have an artifact and a verifier)
$ $GLOSS drift --fail-on none | tail -1
Concepts covered 100% (2/2 with an artifact and a verifier)   ...   Untested: 0   ...
$ $GLOSS impact services/documents/documents/invoice_pdf.py
  hpx:InvoiceDocument (process, implementation, critical): realizes hp:Invoicing
      boundaries: hpb:documents realizes; hpb:harbor realizes
      ! no tests or verifies link; consider adding one
```

**Proposed change.** Credit a verifier of a core concept to an implementation concept only when that implementation concept is the sole realizer of the core concept, or when the test sits in the same boundary as one of its artifacts. Otherwise report it `untested`, as `impact` already does.

**Done when.** The repro reports `untested: hpx:InvoiceDocument` and coverage 1 of 2.

## F-SURF-7: coverage ignores mechanisms that link to core concepts

**Problem.** Coverage counts implementation-tier concepts only. Nothing discourages `implements hp:X` on a core concept: no lint flags it, ADVANCED.md defines `implements` as "the mechanism behind a concept", and ADR 0001's inline form (`@gloss presents pf:X`) targets core directly, so a server-rendered page, a CLI or a BFF that implements a core process directly is a natural reading. MARKING.md's own direct-core examples are `represents` and `verifies`. In those workspaces coverage is `0 of 0` and prints `0%`, and `--fail-under` fails a workspace whose every concept is implemented and tested.

**Repro.** `lab/ambiguous-surfaces/server-page/a-implements` (one concept, implemented by the view and verified by `tests.py`):
```
$ $GLOSS coverage --fail-under 50
concepts 0.0% (0 of 0 implementation concepts have an artifact and a verifier)
...
gloss coverage: concept coverage 0.0% is below --fail-under 50.0%
$ echo $?
1
```
Four of the five `server-page` variants and all five `cli` variants show `0/0` in the tables; the fifth, `d-page-concept`, has an implementation concept and shows `0/1`.

**Proposed change.** Either put in scope every core concept that some artifact `implements` directly, alongside implementation concepts, or add a `gloss check` warning on `implements` of a core concept that says it will not count in coverage. In both cases, when nothing is in scope, print `n/a` and never fail `--fail-under`.

**Done when.** The repro prints `1 of 1` and `100.0%` and exits 0.

## F-SURF-8: represents on an API schema makes the gateway hold the entity

**Problem.** A GraphQL type, an OpenAPI schema or a protobuf message in a gateway looks like a data shape, and `represents` is the documented relation for "data shape". On an entity it lifts to `holds`, so the gateway is recorded as storing orders and the entity's placement moves to the root. GM503 fires, but following its advice by declaring `presents: [hp:Order]` on the gateway clears the warning while the derived `holds` edge and the root placement stay; declaring `holds:` instead would state something false.

**Repro.** `lab/ambiguous-surfaces/graphql/d-schema-represents`, where `gateway/schema.graphql` has `# @gloss represents hp:Order scope=block` above `type Order`:
```
$ $GLOSS check
gateway/schema.graphql:18: warning: represents hp:Order is outside the allowed set derived from gateway/.gloss.yaml (HARD gate); declare the concept there, or write allowed: to widen it (gloss check --explain shows the set) [GM503]
$ grep '"p":"holds"' .glossmark/graph.jsonl | jq -c 'select(.s|endswith("gateway")) | {s,p,o,source}'
{"s":"https://onto.harbor.example/boundaries/hpb/gateway","p":"holds","o":"https://onto.harbor.example/core/Order","source":"derived"}
```
The engineering view places `hp:Order` in `hpb:harbor`; in the other three variants it is in `hpb:orders`. `pdf-invoice/e-represents` shows the same move for `hp:Invoice`.

**Proposed change.** In placement, a boundary whose manifest declares `holds: [X]` beats one that only derives it. In MARKING.md, say that API and wire schemas of an entity stored elsewhere are `presents` (or unmarked), not `represents`. Make GM503 for a `represents` on an entity also suggest `presents` when another boundary already declares `holds` for it.

**Done when.** `graphql/d-schema-represents` places `hp:Order` in `hpb:orders`, and the GM503 message mentions `presents`.

## F-SURF-9: inline presents leaves a surface with no test obligation

**Problem.** ADR 0001 says that after migration "`untested` lists the pages that have no test". That holds only for the page-concept form (`implements .QuotePage` with `QuotePage: { presents: hp:Pricing }`). With the inline form the ADR also offers (`@gloss presents hp:X` on the component), the surface is not a concept, so it can never be untested and never counts in coverage. Its test has nothing honest to verify except the core concept, which inflates that concept's verifiers with a test of a form, and in `pdf-invoice/b-presents-process` trips GM503.

**Repro.** `lab/ambiguous-surfaces/server-page`: `b-presents` reports `presented-only: hp:Pricing` and coverage `0/0`; `d-page-concept`, with the same code and the same test, reports `untested: hpx:QuotePage` and coverage `0/1`. In `admin-limit/a-presents` the page's test `verifies hp:CreditLimit`, the critical rule it does not test.

**Proposed change.** Documentation first: MARKING.md "Pages and shells" should give the decision rule in this file, and say that the inline form is for components with no tests or logic of their own. Optionally, report an inline `presents` artifact whose file has no verifier as `untested` keyed by the artifact.

**Done when.** MARKING.md says when to use each form, or `server-page/b-presents` reports the view as untested.

## F-SURF-10: a presents-only boundary is rated higher than an implementing one

**Problem.** A boundary with no level of its own takes the highest level of what its code realizes, "else its parent boundary's" (GOVERNANCE.md). A surface that only presents realizes nothing, so it takes the whole system's level. The BFF that presents order placement is `critical`; the same BFF that implements it is `high`. Whether a presents-only surface is rated at all depends on its siblings: the storefront in `server-page/b-presents` is `none` because nothing in that system realizes anything.

**Repro.** Boundary nodes in `.glossmark/graph.jsonl`:
```
bff/a-implements:      hpb:mobile-bff high from hp:OrderPlacement
bff/b-presents:        hpb:mobile-bff critical from hpb:harbor
server-page/b-presents: hpb:storefront none from -
```

**Proposed change.** Do not fall back to the parent for a boundary whose code only presents or hosts. Rate it by what it realizes, configures or produces, else leave it unclassified, so a surface's level comes from what it does rather than from its neighbours. A boundary that should inherit can set its own `criticality:` or the parent can set `criticality-floor: true`.

**Done when.** `bff/b-presents` rates `hpb:mobile-bff` at or below the `bff/a-implements` level.

## F-SURF-11: GraphQL SDL is silently not scanned

**Problem.** `.graphql` is not in the comment table. A marker in a schema file is ignored with no message: `build` scans 0 files and `check` passes. The fix is one line in `glossmark.yaml`, but nothing tells the adopter it is needed.

**Repro.** In an empty workspace with only `schema.graphql` containing `# @gloss represents hp:Order`:
```
gloss build: 0 files scanned, 0 markers, ...
```
`gloss check` then prints `0 errors, 0 warnings`. With `comment-styles: { ".graphql": ["#"] }` added: `gloss build: 1 files scanned, 1 marker, ...`. Every `graphql/` workspace here sets it.

**Proposed change.** Add `.graphql` and `.gql` with `#` to the built-in comment table. More generally, have `check` report a file containing `@gloss` whose extension has no comment style.

**Done when.** The repro scans 1 file without `comment-styles`.
