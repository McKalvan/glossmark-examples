# Riverbend Public Library: circulation (CIRC)

**Shape:** brownfield adoption of a fifteen-year-old system. **Shows:** the vocabulary importers (`gloss import --from markdown-glossary` and `--from enums --values`), reviewing the kinds they guess, re-running them, `gloss export --status`; a deprecated concept with `replaced-by:` that code still uses; a `policy.waivers` entry with an expiry; every scope (`line`, `block`, `symbol`, `range` in JSON sidecars, `file`); the legacy `tests` alias (GM240); `has-part`; `represents` on SQL and protobuf; `gloss doctor`; the `coverage --fail-under current` ratchet, `--changed-only` and `--fail-under-files`.

The City of Riverbend wrote CIRC in 2010 and 2011 to replace a vendor circulation system, and has extended it a piece at a time since. Desk staff check items out and in, renew loans and place holds through a Java servlet app. A nightly batch in Ruby, Perl and shell assesses fines, sends overdue notices and expires uncollected holds. Self-checkout kiosks arrived in 2022, and in 2024 the whole thing moved from two on-premises servers to AWS.

| Path | What | Stack | Since |
| --- | --- | --- | --- |
| `src/` | Desk web app: servlets, services, hand-written JDBC DAOs, JSP | Java 11, Servlet 2.5, Ant, JUnit 4 | 2010 |
| `db/` | Numbered schema files and stored procedures | PostgreSQL, PL/pgSQL | 2010 |
| `batch/` | Nightly fines, overdue notices, hold expiry | Ruby, Perl 5, POSIX shell | 2011 (fines in Ruby since 2019) |
| `config/` | Circulation rules, code tables, kiosk settings | YAML, JSON, properties | 2011 to 2024 |
| `kiosk/` | Self-checkout API and its gateway | protobuf (gRPC), Java | 2022 |
| `infra/terraform` | RDS, ECS Fargate, S3, the nightly schedule | Terraform (AWS) | 2024 |
| `Dockerfile` | One image for the web app and the batch | Docker | 2024 |
| `features/` | Acceptance tests | Gherkin (Cucumber-JVM) | 2015 |
| `ill/` | Interlibrary loan, being retired | YAML, Markdown | 2013, code removed 2025 |
| `docs/` | The Circulation glossary, architecture, runbook, fines policy | Markdown | 2012 |

The repository already kept its vocabulary: [docs/glossary.md](docs/glossary.md), maintained by the Circulation department, with a definition, aliases and a status line per term, and [config/enums.yaml](config/enums.yaml), the code tables the Java enums, the Perl jobs and the SQL `CHECK` constraints are generated from. The core tier was imported from those two files, not typed again. The code is realistic but inert: it is never built here.

## The two tiers

**Core, `lib:`** ([ontology/lib.gloss.yaml](ontology/lib.gloss.yaml)) is the glossary plus the code tables. From the glossary: entities (`Patron`, `LibraryCard`, `Branch`, `Title`, `Item`, `Loan`, `Hold`, `Fine`, `LostItem`), processes (`Checkout`, `Checkin`, `Renewal`, `HoldTrapping`, `HoldExpiry`, `FineAssessment`, `OverdueNotification`, `SelfCheckout`, `InterlibraryLoan`), constraints (`LoanPeriod`, `BorrowingLimit`, `PatronBlock`, `GracePeriod`, `FineCap`), and three terms the glossary marks as not built (`TurnoverRate`, `DigitalLending`, `ClaimsReturned`, imported as `proposed: true`). `Borrower` is the pre-2016 name for a patron: `deprecated: true`, `replaced-by: Patron`. From the enums file: `LoanStatus`, `ItemFormat`, `PatronType` and `FineType`, each with its values as `is-a` children. Relations added by hand after the import: `Checkout produces Loan`, `Checkin reverses Checkout`, `SelfCheckout is-a Checkout`, and each constraint `constrains` the process it governs.

**Implementation, `circ:`** ([ontology/circ.gloss.yaml](ontology/circ.gloss.yaml)) was written by hand: three deployables (`CircWebApp`, `KioskGateway`, `NightlyBatch`, which `has-part` its three jobs), the handlers and rules that realize the core processes and constraints, and three `internal` resources from the cloud move. Two rules exist twice, once in Java at check-in and once in the nightly stored procedure (`GracePeriodRule`, `FineCapRule`), and both copies are linked, so a change to one shows the other in `gloss impact`.

## Boundaries

| Manifest | Boundary | Declares |
| --- | --- | --- |
| [.gloss.yaml](.gloss.yaml) | `libb:circ` (system) | `realizes: inherit`; features, docs and the Dockerfile sit directly under it |
| [src/.gloss.yaml](src/.gloss.yaml) | `libb:web` | `realizes` the web app, ten core processes and rules, and the proposed `FinePayment`; `holds` eight entities, `Borrower` among them; `criticality: high` |
| [db/.gloss.yaml](db/.gloss.yaml) | `libb:db` | `realizes` the three procedures' jobs and the two duplicated rules; `holds` eight entities |
| [batch/.gloss.yaml](batch/.gloss.yaml) | `libb:batch` | `realizes` the nightly batch and its jobs |
| [config/.gloss.yaml](config/.gloss.yaml) | `libb:config` | `holds` the four code tables and `Branch` |
| [kiosk/.gloss.yaml](kiosk/.gloss.yaml) | `libb:kiosk` | `realizes` `SelfCheckApi`; `holds` `Loan` (the protobuf `LoanSummary`) |
| [infra/.gloss.yaml](infra/.gloss.yaml) | `libb:infra` | `realizes` the resources and the deployables it provisions |
| [ill/.gloss.yaml](ill/.gloss.yaml) | `libb:ill` | `realizes` `InterlibraryLoan`, which nothing implements any more: the waived gap |

`init` planned manifests for `batch/`, `db/`, `infra/`, `kiosk/` and `src/`. It planned none for `ill/` (no source files left) or `config/`. The `src/` boundary was renamed `libb:web`. `config/` got its own boundary because `holds` has no `inherit` (see the library-legacy rows of [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)): a root that declared the code tables under `holds` would have had to repeat every entity its children hold.

## What the tooling makes of it

Every finding below is intentional. CI compares the full output with [expected-drift.txt](expected-drift.txt) and [expected-check.txt](expected-check.txt), and fails on any violation, gap, value-drift, dangling, rogue or stale finding (`showcase/workspaces.tsv`). The waived gap is listed but does not fail.

| Derived from code | Declared | Result |
| --- | --- | --- |
| nothing under `ill/` implements interlibrary loan; its README `documents` it and `ill.yaml` `configures` it | `libb:ill` realizes `lib:InterlibraryLoan` | **gap**, waived until 2027-06-30: the code went in 2025, the service catalogue keeps ILL until the hand-over |
| the glossary marks three terms "planned" or "not implemented" | the importer wrote `proposed: true` | **proposed** `TurnoverRate`, `DigitalLending`, `ClaimsReturned`, and **orphan**: nothing builds them, which is what the glossary says |
| `FinePaymentServlet` takes payments; the glossary has no term for it | `@gloss? implements lib:NEW:FinePayment`, then `gloss propose --from-new` | **proposed** `lib:FinePayment`, implemented and **untested**; a decision request for the Circulation department |
| the card number is a column on `patrons`; no code shapes a card | `lib:LibraryCard` from the glossary | **orphan** |
| `sp_charge_lost_item` bills a lost item; no marker, because a procedure is not the data shape of an entity | `lib:LostItem` from the glossary | **orphan** |
| `FineType` values appear only as strings in SQL `CHECK` lists | `lib:Overdue` and `lib:Damage` from `enums.yaml --values` | **orphan**: imported enum values nothing names one by one. `ItemFormat`, `PatronType` and `LoanStatus` values are linked through the JSON sidecars and the Java enum |
| `CirculationService.checkin` implements check-in | no test verifies it or `lib:Checkin` | **untested** |
| `assess_fines.rb` and `sp_assess_fines` accrue fines nightly | `FineCalculatorTest` covers the Java copy only | **untested** `NightlyFineJob`: the procedure has no test, as [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) admits |
| the proto service and the gateway implement `SelfCheckApi` | no test | **untested** `lib:SelfCheckout` |
| `Borrower.java` and the `borrowers` view still represent `lib:Borrower`; two manifests hold it | `deprecated: true`, `replaced-by: Patron` | `gloss check` warns **GM222** four times; `gloss drift` says nothing |
| `FineCalculatorTest` carries `@gloss tests ...` with three targets | `tests` is an accepted alias of `verifies` | `gloss check` warns **GM240**, once per target; coverage counts the link as a verifier |

```
$ gloss drift
○ Gaps (declared, not implemented)
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it: ... [ill/.gloss.yaml:1]  (waived: circulation-dept until 2027-06-30)
? Proposed concepts (awaiting acceptance)
  lib:ClaimsReturned is a proposed process by agent:claude-code; accept with gloss accept --concept lib:ClaimsReturned  [ontology/lib.gloss.yaml:122]
  ...
· Orphan concepts (no artifacts)
  lib:ClaimsReturned, lib:Damage, lib:DigitalLending, lib:LibraryCard, lib:LostItem, lib:Overdue, lib:TurnoverRate
△ Implemented but untested
  circ:CheckinHandler, circ:NightlyFineJob, lib:FinePayment, lib:SelfCheckout
Concepts covered 76% (13/17 with an artifact and a verifier)   Files 62% (59/95)   Orphans: 7   Rogue: 0   Violations: 0   Gaps: 1   Stale: 0   Untested: 4   Proposed links: 0   Proposed concepts: 4
```

`expected-check.txt` holds seven warnings, all intentional: four GM222 (the deprecated `Borrower`, used by two code files and declared by two manifests) and three GM240 (one `tests` marker with three targets).

## Importing the vocabulary

The glossary uses `##` headings, `**Def.**`, `**Aliases:**` and `**Status:**` lines, which is what the importer reads. The order of arguments matters: the form in QUICKSTART.md and in the command's own usage line, with the file before `--namespace`, is rejected.

```
$ gloss import --from markdown-glossary docs/glossary.md --namespace lib
usage: gloss import --from markdown-glossary|enums <file> --namespace <ns> [--dry-run] [--values]
$ echo $?
2
$ gloss import --from markdown-glossary --namespace lib docs/glossary.md
gloss import: imported 28 entries from docs/glossary.md into ontology/lib.gloss.yaml: 28 added, 0 updated (doc or aliases), 0 unchanged, 0 skipped
  added: Patron, LibraryCard, Branch, Title, Item, Loan, Checkout, Checkin, Renewal, LoanPeriod, BorrowingLimit, PatronBlock, Hold, HoldTrapping, HoldExpiry, Fine, FineAssessment, GracePeriod, FineCap, OverdueNotification, LostItem, SelfCheckout, InterlibraryLoan, TurnoverRate, DigitalLending, ClaimsReturned, RetiredTerms, Borrower
gloss import: kinds are guessed where the source has none; review them, then gloss check
$ gloss import --from enums --namespace lib --values config/enums.yaml
gloss import: imported 20 entries from config/enums.yaml into ontology/lib.gloss.yaml: 19 added, 1 updated (doc or aliases), 0 unchanged, 0 skipped
  added: LoanStatus, ItemFormat, PatronType, FineType, Overdue, Damage, Book, LargePrint, Dvd, Audiobook, Magazine, Active, LoanStatusOverdue, Returned, Lost, Adult, Juvenile, Senior, Nonresident
  updated: LostItem
```

What the import got right: every definition and alias, `proposed: true` on the three unbuilt terms, `deprecated: true` on `Borrower`, and `is-a` from each enum value to its enum. `gloss check` on the raw import found one thing, `GM340: lib:Borrower: deprecated concepts should carry replaced-by:`.

What the review changed:

| Change | Count | Why |
| --- | --- | --- |
| Kind fixed | 12 of 27 glossary terms | The kind is guessed from the name's ending. `Checkout`, `Checkin`, `Renewal`, `HoldExpiry`, `FineAssessment`, `SelfCheckout`, `InterlibraryLoan` were guessed `entity` and are processes; `LoanPeriod`, `PatronBlock`, `GracePeriod`, `FineCap` were guessed `entity` and are constraints; `ClaimsReturned` was guessed `event` from "-ed". Each fix carries a `# import guessed ...` comment. |
| `replaced-by: Patron` added | 1 | The importer sets `deprecated` and nothing else. |
| Concept deleted, then the source fixed | 1 | The section heading `## Retired terms` became a concept, `RetiredTerms`. Deleting it was undone by the next import, so the heading is now `#`, which the importer ignores. |
| Definition restored | 1 | `FineType`'s value `LOST_ITEM` became `LostItem`, which the glossary already defined; the enum import overwrote the glossary's definition with the fine type's. |
| Relations and criticality added | 15 concepts | `produces`, `consumes`, `reverses`, `constrains`, `is-a`; `criticality: high` on `Patron`, `Fine` and `Checkout`. |
| Enum values renamed | 0 | `FineType`'s `OVERDUE` became `Overdue` and `LoanStatus`'s became `LoanStatusOverdue`, by alphabetical order of the enums. A rename would be re-added as a new concept by the next import, so the names stay as imported. |

### Re-running the importers

The importers are re-runnable: reviewed kinds, comments and relations survive, and a changed definition or alias updates that one line. [demo/reimport.sh](demo/reimport.sh) runs both on a copy, then edits the glossary and runs it again:

```
== 1. re-run both importers on the committed sources

$ gloss import --from markdown-glossary --namespace lib docs/glossary.md
gloss import: imported 27 entries from docs/glossary.md into ontology/lib.gloss.yaml: 0 added, 0 updated (doc or aliases), 27 unchanged, 0 skipped

$ gloss import --from enums --namespace lib --values config/enums.yaml
gloss import: imported 20 entries from config/enums.yaml into ontology/lib.gloss.yaml: 0 added, 1 updated (doc or aliases), 19 unchanged, 0 skipped
  updated: LostItem

$ diff ontology/lib.gloss.yaml (before → after)
100c100
<     doc: "An item the patron has declared lost, or that is 60 days overdue; the patron is billed its replacement cost."
---
>     doc: "Replacement cost charged when an item is declared lost."

== 2. the glossary changes: Renewal gets a limit, Hold an alias, a new term

$ gloss import --from markdown-glossary --namespace lib docs/glossary.md
gloss import: imported 28 entries from docs/glossary.md into ontology/lib.gloss.yaml: 1 added, 2 updated (doc or aliases), 25 unchanged, 0 skipped
  added: HoldShelf
  updated: Renewal, Hold
...
$ grep -c 'import guessed' ontology/lib.gloss.yaml   # the reviewed kinds survived
12
```

The one change a re-run makes on unchanged sources is the `LostItem` collision: each importer writes its own text over the other's on every run. The committed ontology carries the glossary's definition. Run the glossary import after the enums import, or restore the line by hand.

### The status export

`gloss export --status -o docs/vocabulary-status.json` writes one record per owned concept for whatever checks the vocabulary outside GlossMark (the Circulation department's training checklist, here). The committed [docs/vocabulary-status.json](docs/vocabulary-status.json) was written after the last build; `demo/tour.sh` checks it is current.

```
$ jq -r '.[] | .tier + " " + .status' docs/vocabulary-status.json | sort | uniq -c
     38 core implemented
      4 core orphan
      4 core proposed
      1 core untested
     18 implementation implemented
      2 implementation untested
$ jq -c '.[] | select(.concept=="lib:InterlibraryLoan" or .concept=="lib:Borrower")' docs/vocabulary-status.json
{"concept":"lib:Borrower","tier":"core","kind":"entity","status":"implemented","artifacts":2,"verifiers":0,"doc":"The pre-2016 name for a patron."}
{"concept":"lib:InterlibraryLoan","tier":"core","kind":"process","status":"implemented","artifacts":1,"verifiers":0,"findings":["gap"],"doc":"Borrowing a title Riverbend does not own from another library for one patron."}
```

Two things an external checker cannot see from it: the record for `Borrower` has no deprecated flag, and `InterlibraryLoan` is `implemented` because a README `documents` it and a YAML file `configures` it, although drift reports that nothing implements it.

## The deprecated `Borrower`

The glossary's status line, `deprecated in 2016 (CIRC-412); use Patron`, became `deprecated: true`. `replaced-by: Patron` was added by hand. Two files still use the old concept on purpose: [Borrower.java](src/main/java/gov/riverbend/circ/model/Borrower.java) feeds the state library's annual report, whose template still says "borrower", and [007_legacy_borrowers_view.sql](db/schema/007_legacy_borrowers_view.sql) keeps the pre-2016 column names for it.

```
$ gloss check
db/.gloss.yaml:1: warning: lib:Borrower is deprecated; use lib:Patron [GM222]
db/schema/007_legacy_borrowers_view.sql:5: warning: lib:Borrower is deprecated; use lib:Patron [GM222]
src/.gloss.yaml:1: warning: lib:Borrower is deprecated; use lib:Patron [GM222]
src/main/java/gov/riverbend/circ/model/Borrower.java:12: warning: lib:Borrower is deprecated; use lib:Patron [GM222]
...
$ gloss impact src/main/java/gov/riverbend/circ/model/Borrower.java
src/main/java/gov/riverbend/circ/model/Borrower.java  [SOFT, libb:web]
  @gloss represents lib:Borrower  (line 12 Borrower)
  lib:Borrower (entity, core)
      boundaries: libb:circ holds; libb:circ represents; libb:db holds; libb:db represents; libb:web holds; libb:web represents
      also linked from: db/schema/007_legacy_borrowers_view.sql
      ! deprecated; use lib:Patron
```

`gloss drift` and the coverage numbers treat `Borrower` like any other concept. When the state accepts "patron", deleting the two files and the two `holds` entries clears the warnings.

## The waiver

Interlibrary loan intake moved to the Prairie Libraries Consortium in 2025 and its code was removed. The city's service catalogue lists interlibrary loan as a CIRC service until the contract hand-over on 30 June 2027, so `ill/.gloss.yaml` still declares it, and drift reports a gap. The waiver in [glossmark.yaml](glossmark.yaml) silences exactly that finding until then. Its key is the finding's id, which only `gloss drift --format json` prints:

```yaml
policy:
  waivers:
    - { finding: "gap:libb:ill:realizes:lib:InterlibraryLoan", owner: circulation-dept, expires: 2027-06-30, reason: "ILL retiring; consortium takes over 2027-06-30 (CIRC-2210)" }
```

**When it expires**, on 30 June 2027 itself (a copy with `expires:` set to the day of the run already fails), the gap fails `gloss drift` with its default `--fail-on` and with this example's CI kinds, and the line in `expected-drift.txt` changes, so CI goes red until someone removes the `ill/` boundary or extends the waiver. [demo/waiver-expiry.sh](demo/waiver-expiry.sh) sets the date in the past on a copy:

```
$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 2027-06-30 (committed)
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it: ... [ill/.gloss.yaml:1]  (waived: circulation-dept until 2027-06-30)
exit 0

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 2026-06-30
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it: ... [waiver by circulation-dept expired 2026-06-30]  [ill/.gloss.yaml:1]
gloss drift: 1 failing finding (violation,gap,value-drift,dangling,rogue,stale)
exit 1

$ gloss check | tail -1   # check does not mention the expired waiver
gloss check: 0 errors, 7 warnings; 4 proposals, 0 rogues (run gloss status)

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 30 June 2020
  libb:ill declares realizes lib:InterlibraryLoan ... [ill/.gloss.yaml:1]  (waived: circulation-dept until 30 June 2020)
exit 0

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # no expires
  libb:ill declares realizes lib:InterlibraryLoan ... [ill/.gloss.yaml:1]  (waived: circulation-dept until )
exit 0
```

Write `expires:` as an ISO date. In v0.1.0 a date written as `30 June 2020`, or no date at all, waives the finding forever, and neither `check` nor `drift` warns.

## Scopes

| Scope | Where | What it anchors to |
| --- | --- | --- |
| *(none)* | most markers, e.g. [CirculationService.java](src/main/java/gov/riverbend/circ/service/CirculationService.java) `checkout` and `checkin` | the next declaration |
| `symbol` | `assertNotBlocked` in the same file | the method; a Perl `sub` cannot be anchored this way (GM122, see [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)) |
| `line` | the grace-period line in [FineCalculator.java](src/main/java/gov/riverbend/circ/service/FineCalculator.java) and in [sp_assess_fines.sql](db/procs/sp_assess_fines.sql); each constant of [LoanStatus.java](src/main/java/gov/riverbend/circ/model/LoanStatus.java) | the next line: one rule inside a larger function, or one enum value |
| `block` | the five sections of [config/circulation.yaml](config/circulation.yaml) | the indented YAML block below the marker (`fines:` is lines 7 to 13) |
| `range` | [config/loan-rules.json.gloss](config/loan-rules.json.gloss), [patron-types.json.gloss](config/patron-types.json.gloss), [branches.json.gloss](config/branches.json.gloss) | a JSON Pointer in `note=`; see below |
| `file` | the Perl and shell jobs, `web.xml`, the Dockerfile, `enums.yaml`, `batch.yaml`, [kiosk.json.gloss](config/kiosk.json.gloss), the docs | the whole file |

**What `scope=range` does in v0.1.0.** The pointer is recorded as the link's note, but it is not resolved. Every marker in a sidecar anchors to one artifact whose lines and fingerprint are the sidecar's own. So a change to the JSON never makes the link stale, and any edit to the sidecar, its comment included, makes every link in it stale. [demo/sidecar-range.sh](demo/sidecar-range.sh):

```
== 1. artifacts for config/loan-rules.json in the graph
urn:gloss:artifact:config/loan-rules.json#L1  scope=range lines 1-7 (from config/loan-rules.json.gloss)
config/loan-rules.json has 11 lines; the sidecar has 7

== 2. DVD loan period 7 -> 14 days in config/loan-rules.json
stale links: 0

== 3. reword the comment line of config/loan-rules.json.gloss
  config/loan-rules.json.gloss: configures circ:LoanPeriodRule  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:Magazine  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:Audiobook  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:Book  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:Dvd  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:LargePrint  [config/loan-rules.json.gloss]
```

A pointer to a key that does not exist (`/formats/EBOOK`), or a note that is not a pointer at all, passes `gloss check`.

## The legacy `tests` marker

[FineCalculatorTest.java](src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java) carries `// @gloss tests .DeskFineCalculator, .FineCapRule, .GracePeriodRule`, the way a developer used to JUnit's vocabulary writes it. `tests` is an accepted alias of `verifies`: the three concepts count as verified for coverage and `untested` (removing the marker lowers coverage, see the ratchet below). The graph, however, stores it as `tests` edges, nine of them with the boundary lifts, so a query over `graph.jsonl` or the SQLite export for `verifies` misses these three links. `gloss check` asks for `verifies` once per target:

```
src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java:21: warning: prefer verifies: it is the one test relation; tests is an accepted alias that means the same [GM240]
src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java:21: warning: prefer verifies: it is the one test relation; tests is an accepted alias that means the same [GM240]
src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java:21: warning: prefer verifies: it is the one test relation; tests is an accepted alias that means the same [GM240]
```

It stays so the warning has a home in the showcase; `expected-check.txt` pins it.

## The coverage ratchet

CI runs `gloss coverage --fail-under current` for this workspace (`coverage-fail-under` is `current` in `showcase/workspaces.tsv`). The same setting cannot live in `glossmark.yaml`: v0.1.0 reads `policy.coverage-fail-under` as a number, and `current` there makes every command fail with ``cannot unmarshal !!str `current` into float64``. [demo/ratchet.sh](demo/ratchet.sh) checks what that does in each situation CI meets, in a temporary repository where the workspace sits at `showcase/library-legacy` as it does here:

```
== (a) push to main: base = origin/main = HEAD, which has the workspace and its graph
$ gloss coverage --fail-under current
concepts 76.5% (13 of 17 implementation concepts have an artifact and a verifier)
...
exit 0

== (b) first PR: base = HEAD~1, which has no showcase/library-legacy
$ gloss coverage --fail-under current --base HEAD~1
concepts 76.5% (13 of 17 implementation concepts have an artifact and a verifier)
...
exit 0

== (c0) a PR deletes the verifies marker on HoldQueueTest (features/holds.feature still verifies hold trapping)
$ gloss coverage --fail-under current --base HEAD
concepts 76.5% (13 of 17 implementation concepts have an artifact and a verifier)
...
exit 0

== (c) a PR deletes the only test marker on FineCalculatorTest (the legacy 'tests' one)
$ gloss coverage --fail-under current --base HEAD
concepts 58.8% (10 of 17 implementation concepts have an artifact and a verifier)
...
gloss coverage: concept coverage 58.8% is below the base's 76.5% (--fail-under current)
exit 1

== (d) the same change, but origin/main does not exist
$ gloss coverage --fail-under current
gloss: git archive origin/main: exit status 128: fatal: not a valid object name: origin/main
exit 1
```

| Situation | Result | Safe? |
| --- | --- | --- |
| push to main | compares main with itself and passes | yes; the ratchet only bites on pull requests |
| the PR that adds this workspace | the base has no workspace; passes without saying so | yes |
| a PR that lowers concept coverage | fails and names both numbers | this is the ratchet |
| a checkout without `origin/main` | fails with a git error | CI checks out with `fetch-depth: 0`, so `origin/main` exists |

Removing the `verifies` marker on `HoldQueueTest` left coverage unchanged, because `features/holds.feature` also verifies hold trapping, while removing the `tests` marker lowered it. The ratchet counts concepts, not markers.

Because this workspace has no intentional violation, value-drift or dangling finding, `use-action` is `true` and the ratchet runs inside the GlossMark Action, which takes `coverage-fail-under: current` from the registry. The runs above test the binary the Action downloads, not the Action.

**`--changed-only`** scores file coverage over the files changed since the base; concept coverage is unchanged. **`--fail-under-files`** gates on file coverage, and combined with `--changed-only` it gates on the changed files only:

```
$ gloss coverage --changed-only --base HEAD
files 0.0% (0 of 1 files changed since HEAD carry an accepted link)
exit 0
$ gloss coverage --changed-only --fail-under-files 50 --base HEAD
files 0.0% (0 of 1 files changed since HEAD carry an accepted link)
gloss coverage: file coverage 0.0% is below --fail-under-files 50.0%
exit 1
$ gloss coverage --fail-under-files 80
files 61.5% (59 of 96 in-scope files carry an accepted link)
gloss coverage: file coverage 61.5% is below --fail-under-files 80.0%
exit 1
```

For a brownfield repository, `--changed-only --fail-under-files` is the gentle gate: old files stay unmarked until someone touches them.

## Doctor

Run on a committed copy of this repository (the workspace at `showcase/library-legacy`, the root workflow present), which is the state CI sees:

```
$ GLOSS_ACTOR=agent:claude-code gloss doctor
✓ gloss on PATH: /usr/bin/gloss (this build is 0.1.0)
✓ GLOSS_ACTOR: agent:claude-code
! agent hook: no SessionStart hook in .claude/settings.json and no MCP server in .mcp.json → gloss hook install
✓ graph: .glossmark/graph.jsonl matches the tree
✓ ledger: .glossmark/ledger.jsonl is tracked in git
✓ lockfile: no imports, nothing to lock
! CI pins: no GitHub workflow or pre-commit config references GlossMark → add the Action (docs/QUICKSTART.md, section 7) pinned to a release: uses: mckalvan/glossmark@v0.1.0
✓ ontology docs: no truncated docs or null keys; gloss check reports no errors
```

| Line | What it means here |
| --- | --- |
| gloss on PATH | Wrong on the authoring machine: `/usr/bin/gloss` is an unrelated program, and doctor prints its own version, not that binary's. Logged as C4 ([F-ADOPT-3](../../lab/FINDINGS-ADOPTION.md#f-adopt-3-doctor-reports-an-unrelated-gloss-on-path-as-healthy)). |
| GLOSS_ACTOR | Set for agent work. Unset, doctor says new markers would be attributed to `human:<git user>`. |
| agent hook | Deliberate: `init`'s `.claude/settings.json` and `.mcp.json` were removed; only `kitchen-agents` keeps them. |
| graph | The committed graph matches the tree. Before the first commit this line is `✗ ... current but not in git`, and doctor exits 1. |
| ledger | The review record is in git. Same `✗` before the first commit. |
| lockfile | No imports, so nothing to pin. |
| CI pins | A false warning: the repository's root workflow runs the Action with `root: showcase/library-legacy`, but doctor looks only inside the workspace. Logged as C5 ([F-ADOPT-2](../../lab/FINDINGS-ADOPTION.md#f-adopt-2-init-and-doctor-assume-the-workspace-is-the-git-root)). |
| ontology docs | No doc was cut at a comma; every imported doc is quoted. |

Doctor has no advice specific to a brownfield adoption: it does not mention the importers, an expiring waiver or a deprecated concept still in use.

## Run it

```sh
export GLOSS=$PWD/../../.tools/bin/gloss      # from this directory, after scripts/install-gloss.sh
$GLOSS check && $GLOSS drift                   # the table above
demo/tour.sh                                   # version, both importers (dry run), check, coverage, export --status, doctor
demo/reimport.sh                               # re-running the importers
demo/waiver-expiry.sh                          # the waiver, expired and malformed
demo/sidecar-range.sh                          # what scope=range anchors to
demo/ratchet.sh                                # coverage --fail-under current, --changed-only, --fail-under-files
```

## How it was adopted

The code was written first with no GlossMark files. Then, in order:

1. `gloss init --dry-run` guessed `ll:`, `lli:` and `llb:` from `library-legacy` and planned manifests on `batch/`, `db/`, `infra/`, `kiosk/` and `src/`. It did not mention the glossary or the enums file.
2. `gloss init --core lib --impl circ --iri https://onto.riverbend.example/library/`; its workflow and hook files were removed.
3. `gloss import` for the glossary and the enums file, then the review above.
4. The implementation tier by hand, manifests filled, `config/` and `ill/` boundaries added.
5. `gloss suggest`: 74 proposals (34 Java, 16 SQL, 14 Terraform, 6 protobuf, 4 Gherkin; none for Perl, shell, Ruby, YAML, JSON, Markdown, XML or the Dockerfile). 21 kept, 22 retargeted, 31 deleted. 46 more markers were written by hand.
6. `gloss propose --from-new` for `FinePayment`, `gloss accept --policy` (82 links) then `gloss accept --all` (7). The 25 `scope=file` and sidecar links went stale on acceptance (C13, [F-ADOPT-8](../../lab/FINDINGS-ADOPTION.md#f-adopt-8-accepting-a-scopefile-proposal-makes-it-stale-and-it-cannot-be-re-confirmed)); the stale ledger lines were dropped and `gloss build` re-recorded them as accepted.
7. The waiver, the goldens, `gloss export --status` last.

The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them. The proposed concepts wait for the Circulation department. Every friction point is in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md).
