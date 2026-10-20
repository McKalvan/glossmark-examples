# Hypothesis: ambiguous surfaces

## The question

[ADR 0001](https://github.com/McKalvan/GlossMark/blob/main/docs/adr/0001-presents-and-hosts.md) splits "this code stands for concept X" into three relations: `implements` (the mechanism), `presents` (a UI surface: page, screen, view, report) and `hosts` (a shell: app frame, router, plugin host). The ADR's own examples are clean: a React page that only shows data, an engine that only computes it, an app frame that only routes.

Real code is rarely that clean. This experiment takes six surfaces where the choice is genuinely unclear and asks what each choice does to the four things an adopter relies on:

| Signal | Command |
| --- | --- |
| Drift: `presented-only`, `untested`, `violation`, `gap` | `gloss drift --fail-on none --format json` |
| Coverage | `gloss coverage --format json` |
| Criticality of the surface's own files | the artifact nodes in `.glossmark/graph.jsonl`, and `gloss impact <file>` |
| Boundary placement | the `boundary` of each core concept in the business view of `gloss view --json` |

## Why it matters

An adopter marks a surface once and then trusts four numbers that depend on the choice. If `presents` silently removes a file from criticality and from `untested`, a page that edits a critical setting or computes a price is reviewed like a dashboard. If `implements` is chosen instead, the concept gets two mechanisms, and the viewer may lift it out of the engine's box. A new user needs a rule that picks the right relation, and lints that catch the wrong one.

## The six cases

Harbor Provisions, a wholesale food distributor that sells to restaurants on account. Each case is one directory with side-by-side variant workspaces. Within a case the code and tests are byte-identical; only `@gloss` lines, the ontology and the manifests differ (`run.sh` checks this).

| Case | The surface | Why it is ambiguous |
| --- | --- | --- |
| `bff` | A mobile backend-for-frontend route that aggregates the order and credit backends into a "reorder" card | It reshapes data for one client (a surface), and it re-applies the credit-limit rule to decide whether the reorder button is enabled (a mechanism) |
| `server-page` | A Django view that renders the quote page and computes the line price and volume discount inline | The page is the only place the price is computed |
| `cli` | `hpctl close-period`, a Click command that closes an accounting period | The command is the user surface and the whole mechanism |
| `graphql` | A GraphQL schema and resolver layer in front of the order service | Resolvers delegate, but also authorize and compute a field; schema types look like data shapes |
| `admin-limit` | An admin page that edits a customer's credit limit, a critical constraint whose engine lives in another service | It shows the constraint, and it changes the constraint's value |
| `pdf-invoice` | A ReportLab invoice renderer whose output is the legal invoice | It is a report (a surface), and its output is the product |

## What "GlossMark handles this well" looks like

Each item names the command and the output that would confirm it. `FINDINGS.md` answers them one by one.

1. **H1. A surface keeps a test obligation.** For a page marked inline `presents hp:X` with no test of its own, `gloss drift` or `gloss coverage` still shows that the surface is untested, the way it does for an implementation page concept (`untested` in clinic-booking).
2. **H2. A file that changes a critical value is critical.** In `admin-limit`, some relation that is true of the page (it presents or configures the constraint) makes the page's artifact node carry `criticality: critical`, and `gloss impact apps/admin/src/pages/CreditLimitPage.tsx` says so, without claiming the page implements the rule.
3. **H3. Surface plus inline logic can say both.** A Django view or BFF route can carry `presents hp:X` and `implements hp:Y` (or `implements hp:X`) on one declaration without a lint warning; `presented-only` then clears and the artifact takes the implemented concept's level.
4. **H4. Surfaces never move a concept out of its engine's box.** For every variant, a core concept that an engine boundary realizes is placed in that engine's boundary in the business view of `gloss view --json`, whatever the surface is marked with.
5. **H5. `presented-only` means "no mechanism".** It fires when a page presents a concept nothing implements (`server-page` and `cli` marked `presents` only), and it does not fire when the concept is an entity that a model `represents` (`pdf-invoice`).
6. **H6. Wrong relations are caught.** `gloss check` warns when `hosts` targets something that is not hostable (a process, constraint or entity), because `hosts` is exempt from `presented-only` and would otherwise hide a missing mechanism.
7. **H7. Data shapes in an API schema do not become storage.** GraphQL types marked `represents hp:Order` do not make the gateway boundary `hold` orders, and do not take the concept's placement away from the service that stores it.
8. **H8. The reports agree.** `gloss export --status` and `gloss drift` give the same status for a concept: one `drift` calls `presented-only` is not `implemented` in the status export.
9. **H9. The choice is visible where it matters.** The variants of each case differ in at least one of the four signals, so the choice is not cosmetic, and a decision rule can be derived from the differences.
