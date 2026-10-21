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

`init` planned manifests for `batch/`, `db/`, `infra/`, `kiosk/` and `src/`. It planned none for `ill/` (no source files left) or `config/`. The `src/` boundary was renamed `libb:web`. `config/` got its own boundary because `holds` had no `inherit` in v0.1.0 (L19 in the library-legacy rows of [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)): a root that declared the code tables under `holds` would have had to repeat every entity its children hold. The pinned GlossMark accepts `holds: [inherit, lib:LoanStatus]` (GlossMark ADR 0026); the `config/` boundary stays.

## What the tooling makes of it

Every finding below is intentional. CI compares the full output with [expected-drift.txt](expected-drift.txt) and [expected-check.txt](expected-check.txt), and fails on any violation, gap, value-drift, dangling, rogue or stale finding (`showcase/workspaces.tsv`). The waived gap is listed but does not fail.

| Derived from code | Declared | Result |
| --- | --- | --- |
| nothing under `ill/` implements interlibrary loan; its README `documents` it and `ill.yaml` `configures` it | `libb:ill` realizes `lib:InterlibraryLoan` | **gap**, waived until 2027-06-30: the code went in 2025, the service catalogue keeps ILL until the hand-over. The line now names the link it found: `its code configures it instead: declare configures, or change the marker` |
| the glossary marks three terms "planned" or "not implemented" | the importer wrote `proposed: true` | **proposed** `TurnoverRate`, `DigitalLending`, `ClaimsReturned`, and **orphan**: nothing builds them, which is what the glossary says |
| `FinePaymentServlet` takes payments; the glossary has no term for it | `@gloss? implements lib:NEW:FinePayment`, then `gloss propose --from-new` | **proposed** `lib:FinePayment`, implemented and **untested**; a decision request for the Circulation department |
| the card number is a column on `patrons`; no code shapes a card | `lib:LibraryCard` from the glossary | **orphan** |
| `sp_charge_lost_item` bills a lost item; no marker, because a procedure is not the data shape of an entity | `lib:LostItem` from the glossary | **orphan** |
| `FineType` values appear only as strings in SQL `CHECK` lists | `lib:Overdue` and `lib:Damage` from `enums.yaml --values` | **orphan**: imported enum values nothing names one by one. `ItemFormat`, `PatronType` and `LoanStatus` values are linked through the JSON sidecars and the Java enum |
| `CirculationService.checkin` implements check-in | no test verifies it or `lib:Checkin` | **untested** |
| `assess_fines.rb` and `sp_assess_fines` accrue fines nightly | `FineCalculatorTest` covers the Java copy only | **untested** `NightlyFineJob`: the procedure has no test, as [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) admits |
| the proto service and the gateway implement `SelfCheckApi` | no test | **untested** `lib:SelfCheckout` |
| `Borrower.java` and the `borrowers` view still represent `lib:Borrower`; two manifests hold it | `deprecated: true`, `replaced-by: Patron` | `gloss check` warns **GM222** four times; `gloss drift` lists the same four under **Deprecated in use**, which does not fail by default (v0.1.0 drift said nothing) |
| `FineCalculatorTest` carries `@gloss tests ...` with three targets | `tests` is an accepted alias of `verifies` | `gloss check` warns **GM240** once for the marker (v0.1.0 warned once per target); coverage counts the link as a verifier |

```
$ gloss drift
Ontology drift

○ Gaps (declared, not implemented)
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it; its code configures it instead: declare configures, or change the marker  [ill/.gloss.yaml:1]  (waived: circulation-dept until 2027-06-30)

? Proposed concepts (awaiting acceptance)
  lib:ClaimsReturned is a proposed process by agent:claude-code; accept with gloss accept --concept lib:ClaimsReturned  [ontology/lib.gloss.yaml:122]
  lib:DigitalLending is a proposed process by agent:claude-code; accept with gloss accept --concept lib:DigitalLending  [ontology/lib.gloss.yaml:116]
  lib:FinePayment is a proposed process by agent:claude-code; accept with gloss accept --concept lib:FinePayment  [ontology/lib.gloss.yaml:185]
  lib:TurnoverRate is a proposed measure by agent:claude-code; accept with gloss accept --concept lib:TurnoverRate  [ontology/lib.gloss.yaml:110]

· Orphan concepts (no artifacts)
  lib:ClaimsReturned: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:122]
  lib:Damage: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:148]
  lib:DigitalLending: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:116]
  lib:LibraryCard: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:13]
  lib:LostItem: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:98]
  lib:Overdue: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:145]
  lib:TurnoverRate: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/lib.gloss.yaml:110]

△ Implemented but untested
  circ:CheckinHandler is implemented but nothing tests or verifies it; lib:Checkin, which it realizes, counts as tested only because circ:CircWebApp is tested  [ontology/circ.gloss.yaml:27]
  circ:NightlyFineJob is implemented but nothing tests or verifies it; lib:FineAssessment, which it realizes, counts as tested only because circ:DeskFineCalculator, circ:NightlyBatch are tested  [ontology/circ.gloss.yaml:65]
  lib:FinePayment is implemented but nothing tests or verifies it  [ontology/lib.gloss.yaml:185]
  lib:SelfCheckout is implemented but nothing tests or verifies it  [ontology/lib.gloss.yaml:101]

~ Deprecated in use
  libb:db holds lib:Borrower: deprecated; replaced-by lib:Patron  [db/.gloss.yaml:1]
  db/schema/007_legacy_borrowers_view.sql:5 represents lib:Borrower: deprecated; replaced-by lib:Patron  [db/schema/007_legacy_borrowers_view.sql:5]
  libb:web holds lib:Borrower: deprecated; replaced-by lib:Patron  [src/.gloss.yaml:1]
  src/main/java/gov/riverbend/circ/model/Borrower.java:12 represents lib:Borrower: deprecated; replaced-by lib:Patron  [src/main/java/gov/riverbend/circ/model/Borrower.java:12]

Decision requests
  accept or reject proposed lib:ClaimsReturned (ontology/lib.gloss.yaml:122)
  accept or reject proposed lib:DigitalLending (ontology/lib.gloss.yaml:116)
  accept or reject proposed lib:FinePayment (ontology/lib.gloss.yaml:185)
  accept or reject proposed lib:TurnoverRate (ontology/lib.gloss.yaml:110)

Concepts covered 76% (13/17 with an artifact and a verifier)   Orphans: 7   Rogue: 0   Violations: 0   Gaps: 1   Stale: 0   Untested: 4   Proposed links: 0   Proposed concepts: 4
```

`expected-check.txt` holds five warnings, all intentional: four GM222 (the deprecated `Borrower`, used by two code files and declared by two manifests) and one GM240 (one `tests` marker). With v0.1.0 there were seven: GM240 came once per target.

## Importing the vocabulary

The glossary uses `##` headings, `**Def.**`, `**Aliases:**` and `**Status:**` lines, which is what the importer reads. With v0.1.0 the order of arguments mattered: the form in QUICKSTART.md and in the command's own usage line, with the file before `--namespace`, was rejected. The pinned GlossMark accepts both orders (`gloss import --from markdown-glossary docs/glossary.md --namespace lib --dry-run` exits 0). The adoption transcript, run with v0.1.0:

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
| Definition restored | 1 | `FineType`'s value `LOST_ITEM` became `LostItem`, which the glossary already defined; the v0.1.0 enum import overwrote the glossary's definition with the fine type's. |
| Relations and criticality added | 15 concepts | `produces`, `consumes`, `reverses`, `constrains`, `is-a`; `criticality: high` on `Patron`, `Fine` and `Checkout`. |
| Enum values renamed | 0 | `FineType`'s `OVERDUE` became `Overdue` and `LoanStatus`'s became `LoanStatusOverdue`, by alphabetical order of the enums. A rename would be re-added as a new concept by the next import, so the names stay as imported. |

### Re-running the importers

The importers are re-runnable: reviewed kinds, comments and relations survive, and a changed definition or alias updates that one line. [demo/reimport.sh](demo/reimport.sh) runs both on a copy, then edits the glossary and runs it again:

```
== 1. re-run both importers on the committed sources

$ gloss import --from markdown-glossary --namespace lib docs/glossary.md
gloss import: imported 27 entries from docs/glossary.md into ontology/lib.gloss.yaml: 0 added, 0 updated (doc or aliases), 27 unchanged, 0 skipped

$ gloss import --from enums --namespace lib --values config/enums.yaml
gloss import: imported 20 entries from config/enums.yaml into ontology/lib.gloss.yaml: 1 added, 0 updated (doc or aliases), 19 unchanged, 0 skipped
  added: FineTypeLostItem
gloss import: kinds are guessed where the source has none (a **Kind:** line sets one); review them, then gloss check. .glossmark/import-record.jsonl records what was imported; commit it

$ diff ontology/lib.gloss.yaml (before → after)
189a190,192
>   FineTypeLostItem:
>     is-a: FineType
>     doc: "Replacement cost charged when an item is declared lost."

== 2. the glossary changes: Renewal gets a limit, Hold an alias, a new term

$ gloss import --from markdown-glossary --namespace lib docs/glossary.md
gloss import: imported 28 entries from docs/glossary.md into ontology/lib.gloss.yaml: 1 added, 2 updated (doc or aliases), 25 unchanged, 0 skipped
  added: HoldShelf (entity, guessed from the name)
  updated: Renewal, Hold
gloss import: kinds are guessed where the source has none (a **Kind:** line sets one); review them, then gloss check. .glossmark/import-record.jsonl records what was imported; commit it

$ diff ontology/lib.gloss.yaml (before → after)
46c46
<     doc: "Extending a loan by one more loan period without bringing the item in."
---
>     doc: "Extending a loan by one more loan period without bringing the item in; at most twice."
65c65
<     aliases: [reserve, request]
---
>     aliases: [reserve, request, hold request]
189a190,192
>   HoldShelf:
>     kind: entity
>     doc: "The shelf behind the desk where trapped holds wait for pickup."

$ grep -c 'import guessed' ontology/lib.gloss.yaml   # the reviewed kinds survived
12
```

The one change a re-run makes on unchanged sources comes from the `LostItem` collision. With v0.1.0 each importer wrote its own text over the other's on every run. The pinned GlossMark no longer overwrites a concept another source defined: the enums import adds `FineTypeLostItem` for the fine type instead. The committed ontology was imported with v0.1.0 and carries the glossary's definition on `LostItem` and no `FineTypeLostItem`, so the first re-run adds it. The importers also write `.glossmark/import-record.jsonl` now.

### The status export

`gloss export --status -o docs/vocabulary-status.json` writes one record per owned concept for whatever checks the vocabulary outside GlossMark (the Circulation department's training checklist, here). The committed [docs/vocabulary-status.json](docs/vocabulary-status.json) was written by v0.1.0, and `demo/tour.sh`, which checks it is current, reports `docs/vocabulary-status.json differs` with the pinned GlossMark. It has not been regenerated. The output below is the v0.1.0 file; what the pinned GlossMark writes follows it.

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

Two things an external checker could not see from the v0.1.0 file: the record for `Borrower` has no deprecated flag, and `InterlibraryLoan` is `implemented` because a README `documents` it and a YAML file `configures` it, although drift reports that nothing implements it (L28). The pinned GlossMark fixes both, and also counts the enum values linked only by `configures` in the JSON sidecars (`Book`, `Dvd`, `Adult` ...) as `unimplemented`:

```
$ gloss export --status -o status.json && jq -r '.[] | .tier + " " + .status' status.json | sort | uniq -c
     28 core implemented
      4 core orphan
      4 core proposed
     10 core unimplemented
      1 core untested
     18 implementation implemented
      2 implementation untested
$ jq -c '.[] | select(.concept=="lib:InterlibraryLoan" or .concept=="lib:Borrower")' status.json
{"concept":"lib:Borrower","tier":"core","kind":"entity","status":"implemented","artifacts":2,"verifiers":0,"findings":["deprecated-use","overlap"],"deprecated":true,"replaced-by":"lib:Patron","doc":"The pre-2016 name for a patron."}
{"concept":"lib:InterlibraryLoan","tier":"core","kind":"process","status":"unimplemented","artifacts":0,"verifiers":0,"findings":["gap"],"doc":"Borrowing a title Riverbend does not own from another library for one patron."}
```

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
src/main/java/gov/riverbend/circ/model/Borrower.java  [HARD, libb:web]
  @gloss represents lib:Borrower  (line 12 Borrower)
  lib:Borrower (entity, core)
      boundaries: libb:circ holds; libb:circ represents; libb:db holds; libb:db represents; libb:web holds; libb:web represents
      also linked from: db/schema/007_legacy_borrowers_view.sql
      ! deprecated; use lib:Patron
```

`gloss drift` lists the four uses under **Deprecated in use** (`libb:db holds lib:Borrower: deprecated; replaced-by lib:Patron`), a kind that does not fail by default; v0.1.0 drift treated `Borrower` like any other concept. The coverage numbers still do. When the state accepts "patron", deleting the two files and the two `holds` entries clears the warnings and the drift lines.

## The waiver

Interlibrary loan intake moved to the Prairie Libraries Consortium in 2025 and its code was removed. The city's service catalogue lists interlibrary loan as a CIRC service until the contract hand-over on 30 June 2027, so `ill/.gloss.yaml` still declares it, and drift reports a gap. The waiver in [glossmark.yaml](glossmark.yaml) silences exactly that finding until then. Its key is the finding's id, which `gloss drift --ids` prints at the end of each line and `gloss drift --format json` as `id` (v0.1.0 had only the JSON):

```yaml
policy:
  waivers:
    - { finding: "gap:libb:ill:realizes:lib:InterlibraryLoan", owner: circulation-dept, expires: 2027-06-30, reason: "ILL retiring; consortium takes over 2027-06-30 (CIRC-2210)" }
```

**When it expires**, the day after 30 June 2027 (`expires` is inclusive: a copy with `expires:` set to the day of the run still passes; with v0.1.0 it already failed), the gap fails `gloss drift` with its default `--fail-on` and with this example's CI kinds, and the line in `expected-drift.txt` changes, so CI goes red until someone removes the `ill/` boundary or extends the waiver. [demo/waiver-expiry.sh](demo/waiver-expiry.sh) sets the date in the past on a copy:

```
$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 2027-06-30 (committed)
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it; its code configures it instead: declare configures, or change the marker  [ill/.gloss.yaml:1]  (waived: circulation-dept until 2027-06-30)
exit 0

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 2026-06-30
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it; its code configures it instead: declare configures, or change the marker [waiver by circulation-dept expired 2026-06-30]  [ill/.gloss.yaml:1]
gloss drift: 1 failing finding (violation,gap,value-drift,dangling,rogue,stale)
exit 1

$ gloss check | tail -1   # check does not mention the expired waiver
gloss check: 0 errors, 6 warnings; 4 proposals, 0 rogues (run gloss status)

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # expires: 30 June 2020
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it; its code configures it instead: declare configures, or change the marker [waiver by circulation-dept ignored: expires "30 June 2020" is not a YYYY-MM-DD date]  [ill/.gloss.yaml:1]
gloss drift: 1 failing finding (violation,gap,value-drift,dangling,rogue,stale)
exit 1

$ gloss drift --fail-on violation,gap,value-drift,dangling,rogue,stale   # no expires
  libb:ill declares realizes lib:InterlibraryLoan but nothing under it implements it; its code configures it instead: declare configures, or change the marker [waiver by circulation-dept ignored: expires "" is not a YYYY-MM-DD date]  [ill/.gloss.yaml:1]
gloss drift: 1 failing finding (violation,gap,value-drift,dangling,rogue,stale)
exit 1
```

Write `expires:` as an ISO date. The pinned GlossMark ignores a waiver whose `expires:` is missing or not `YYYY-MM-DD`, so drift fails as above, and `gloss check` fails it (`expires "30 June 2020" is not a YYYY-MM-DD date; a waiver must expire [GM610]`). An expired waiver is a check warning (GM612), which is the sixth warning in the count above; the demo's comment that check does not mention it dates from v0.1.0. In v0.1.0 a date written as `30 June 2020`, or no date at all, waived the finding forever, and neither `check` nor `drift` warned (L25).

## Scopes

| Scope | Where | What it anchors to |
| --- | --- | --- |
| *(none)* | most markers, e.g. [CirculationService.java](src/main/java/gov/riverbend/circ/service/CirculationService.java) `checkout` and `checkin` | the next declaration |
| `symbol` | `assertNotBlocked` in the same file | the method. A Perl `sub` anchors too now (GlossMark #156); in v0.1.0 it could not (GM122, see [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)) |
| `line` | the grace-period line in [FineCalculator.java](src/main/java/gov/riverbend/circ/service/FineCalculator.java) and in [sp_assess_fines.sql](db/procs/sp_assess_fines.sql); each constant of [LoanStatus.java](src/main/java/gov/riverbend/circ/model/LoanStatus.java) | the next line: one rule inside a larger function, or one enum value |
| `block` | the five sections of [config/circulation.yaml](config/circulation.yaml) | the indented YAML block below the marker (`fines:` is lines 7 to 13) |
| `range` | [config/loan-rules.json.gloss](config/loan-rules.json.gloss), [patron-types.json.gloss](config/patron-types.json.gloss), [branches.json.gloss](config/branches.json.gloss) | the value a JSON Pointer in `note=` names in the annotated file; see below |
| `file` | the Perl and shell jobs, `web.xml`, the Dockerfile, `enums.yaml`, `batch.yaml`, [kiosk.json.gloss](config/kiosk.json.gloss), the docs | the whole file |

**What `scope=range` does.** Since GlossMark #116 each marker resolves its JSON Pointer against the annotated JSON file: every pointer is its own artifact, anchored to the lines of the value it names and fingerprinted by that value. A change to the JSON makes the links whose value changed stale (the DVD entry and the `/formats` object that contains it), and nothing else. In v0.1.0 the pointer was only a note: every marker in a sidecar anchored to one artifact whose lines and fingerprint were the sidecar's own, so a change to the JSON never made a link stale and any edit to the sidecar staled every link in it. The new anchors staled `kiosk.json.gloss`'s link once, which was re-confirmed when the pin moved (GlossMark #171). [demo/sidecar-range.sh](demo/sidecar-range.sh) (its steps run in sequence, so step 3 still shows the two links step 2 staled):

```
== 1. artifacts for config/loan-rules.json in the graph
urn:gloss:artifact:config/loan-rules.json#/formats  scope=range lines 4-10 (from config/loan-rules.json.gloss)
urn:gloss:artifact:config/loan-rules.json#/formats/AUDIOBOOK  scope=range lines 8-8 (from config/loan-rules.json.gloss)
urn:gloss:artifact:config/loan-rules.json#/formats/BOOK  scope=range lines 5-5 (from config/loan-rules.json.gloss)
urn:gloss:artifact:config/loan-rules.json#/formats/DVD  scope=range lines 7-7 (from config/loan-rules.json.gloss)
urn:gloss:artifact:config/loan-rules.json#/formats/LARGE_PRINT  scope=range lines 6-6 (from config/loan-rules.json.gloss)
urn:gloss:artifact:config/loan-rules.json#/formats/MAGAZINE  scope=range lines 9-9 (from config/loan-rules.json.gloss)
config/loan-rules.json has 11 lines; the sidecar has 7

== 2. DVD loan period 7 -> 14 days in config/loan-rules.json
stale links: 2

== 3. reword the comment line of config/loan-rules.json.gloss
  config/loan-rules.json.gloss: configures circ:LoanPeriodRule  [config/loan-rules.json.gloss]
  config/loan-rules.json.gloss: configures lib:Dvd  [config/loan-rules.json.gloss]
```

A pointer to a key that does not exist (`/formats/EBOOK`), or a note that is not a pointer at all, is a `gloss check` warning and anchors to the sidecar (`JSON Pointer /formats/EBOOK does not resolve in config/loan-rules.json; anchored to the sidecar [GM123]`). In v0.1.0 both passed silently.

## The legacy `tests` marker

[FineCalculatorTest.java](src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java) carries `// @gloss tests .DeskFineCalculator, .FineCapRule, .GracePeriodRule`, the way a developer used to JUnit's vocabulary writes it. `tests` is an accepted alias of `verifies`: the three concepts count as verified for coverage and `untested` (removing the marker lowers coverage, see the ratchet below). The graph stores it as `verifies`, so a query over `graph.jsonl` for `verifies` finds these links; `grep -c '"p":"tests"' .glossmark/graph.jsonl` is 0. In v0.1.0 they were nine `tests` edges (L21). `gloss check` asks for `verifies` once for the marker (v0.1.0 asked once per target):

```
src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java:21: warning: prefer verifies: it is the one test relation; tests is an accepted alias that means the same [GM240]
```

It stays so the warning has a home in the showcase; `expected-check.txt` pins it.

## The coverage ratchet

CI runs `gloss coverage --fail-under current` for this workspace (`coverage-fail-under` is `current` in `showcase/workspaces.tsv`). The registry keeps it because v0.1.0 could not take it in `glossmark.yaml`: it read `policy.coverage-fail-under` as a number, and `current` there made every command fail with ``cannot unmarshal !!str `current` into float64`` (L32). The pinned GlossMark accepts `coverage-fail-under: current` in the policy (`gloss check` passes with it). [demo/ratchet.sh](demo/ratchet.sh) checks what that does in each situation CI meets, in a temporary repository where the workspace sits at `showcase/library-legacy` as it does here:

```
== (a) push to main: base = origin/main = HEAD, which has the workspace and its graph
$ gloss coverage --fail-under current
concepts 76.5% (13 of 17 concepts in scope have an artifact and a verifier: implementation concepts, and core concepts code implements directly)
...
exit 0

== (b) first PR: base = HEAD~1, which has no showcase/library-legacy
$ gloss coverage --fail-under current --base HEAD~1
gloss coverage: base HEAD~1 has no workspace at showcase/library-legacy (no glossmark.yaml); ratchet skipped
concepts 76.5% (13 of 17 concepts in scope have an artifact and a verifier: implementation concepts, and core concepts code implements directly)
...
exit 0

== (c0) a PR deletes the verifies marker on HoldQueueTest (features/holds.feature still verifies hold trapping)
$ gloss coverage --fail-under current --base HEAD
concepts 76.5% (13 of 17 concepts in scope have an artifact and a verifier: implementation concepts, and core concepts code implements directly)
...
exit 0

== (c) a PR deletes the only test marker on FineCalculatorTest (the legacy 'tests' one)
$ gloss coverage --fail-under current --base HEAD
concepts 58.8% (10 of 17 concepts in scope have an artifact and a verifier: implementation concepts, and core concepts code implements directly)
...
gloss coverage: concept coverage 58.8% is below the base's 76.5% (--fail-under current)
exit 1

== (d) the same change, but origin/main does not exist
$ gloss coverage --fail-under current
gloss: base origin/main is not a commit in this repository; fetch it (git fetch origin main, or a deeper clone in CI) or name another ref with --base <ref>
exit 1
```

| Situation | Result | Safe? |
| --- | --- | --- |
| push to main | compares main with itself and passes | yes; the ratchet only bites on pull requests |
| the PR that adds this workspace | the base has no workspace; passes and says `ratchet skipped` (v0.1.0 said nothing) | yes |
| a PR that lowers concept coverage | fails and names both numbers | this is the ratchet |
| a checkout without `origin/main` | fails and says to fetch `origin/main` or pass `--base` (v0.1.0 printed the raw git error) | CI checks out with `fetch-depth: 0`, so `origin/main` exists |

Removing the `verifies` marker on `HoldQueueTest` left coverage unchanged, because `features/holds.feature` also verifies hold trapping, while removing the `tests` marker lowered it. The ratchet counts concepts, not markers.

Because this workspace has no intentional violation, value-drift or dangling finding, `use-action` is `true` and the ratchet runs inside the GlossMark Action, which takes `coverage-fail-under: current` from the registry. The runs above test the pinned binary, not the Action.

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
files 62.1% (59 of 95 in-scope files carry an accepted link)
gloss coverage: file coverage 62.1% is below --fail-under-files 80.0%
exit 1
```

For a brownfield repository, `--changed-only --fail-under-files` is the gentle gate: old files stay unmarked until someone touches them.

## Doctor

Run on a committed copy of this repository (the workspace at `showcase/library-legacy`, the root workflow present), which is the state CI sees:

```
$ GLOSS_ACTOR=agent:claude-code gloss doctor
✗ gloss on PATH: not found; the SessionStart hook and the MCP server run `gloss` by name and fail silently without it → curl -fsSL https://raw.githubusercontent.com/mckalvan/glossmark/main/install.sh | sh, or go install github.com/mckalvan/glossmark/cmd/gloss@v0.1.0, then add the directory to PATH
✓ GLOSS_ACTOR: agent:claude-code
! agent hook: no SessionStart hook in .claude/settings.json and no MCP server in .mcp.json → gloss hook install
✓ graph: .glossmark/graph.jsonl matches the tree
✓ ledger: .glossmark/ledger.jsonl is tracked in git
✓ lockfile: no imports, nothing to lock
! CI pins: no GitHub workflow at the git root (/home/user/glossmark-examples) or in this workspace references GlossMark for this workspace → add the Action pinned to a release to a workflow at the git root, with root: set to this workspace: uses: mckalvan/glossmark@v0.1.0
✓ ontology docs: no truncated docs or null keys; gloss check reports no errors
✓ waivers: 1 waiver(s), none expiring within 30 days
✓ auto-accept: conf >= 0.70 (policy.soft-conf-threshold); on the shipped calibration: precision 84.0%, 46.2% of proposals (150 of 325)
```

| Line | What it means here |
| --- | --- |
| gloss on PATH | Correct: no `gloss` is on `PATH` in this checkout, which the hook and the MCP server would need. Doctor now runs the binary it finds and reports an unrelated program (`... is not GlossMark (... printed "GNU gloss 2.1")`). In v0.1.0 it called `/usr/bin/gloss` on the authoring machine healthy and printed its own version (C4, [F-ADOPT-3](../../lab/FINDINGS-ADOPTION.md#f-adopt-3-doctor-reports-an-unrelated-gloss-on-path-as-healthy)). |
| GLOSS_ACTOR | Set for agent work. Unset, doctor says new markers would be attributed to `human:<git user>`. |
| agent hook | Deliberate: `init`'s `.claude/settings.json` and `.mcp.json` were removed; only `kitchen-agents` keeps them. |
| graph | The committed graph matches the tree. Before the first commit this line is `✗ ... current but not in git`, and doctor exits 1. |
| ledger | The review record is in git. Same `✗` before the first commit. |
| lockfile | No imports, so nothing to pin. |
| CI pins | Still a false warning. Doctor now reads the workflows at the git root, but the root workflow runs the Action with `root: ${{ matrix.root }}` from the registry, which doctor does not match to this workspace. It also suggests `@v0.1.0`, not the pinned commit. Logged as C5 ([F-ADOPT-2](../../lab/FINDINGS-ADOPTION.md#f-adopt-2-init-and-doctor-assume-the-workspace-is-the-git-root)). |
| ontology docs | No doc was cut at a comma; every imported doc is quoted. |
| waivers | New: lists waivers that expired or expire within 30 days. It still reports `none expiring` for a waiver whose `expires:` is malformed, which `gloss check` fails (GM610). |
| auto-accept | New: what `soft-conf-threshold` means on GlossMark's shipped calibration set. |

Doctor now mentions waivers. It still says nothing about the importers or a deprecated concept still in use.

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
6. `gloss propose --from-new` for `FinePayment`, `gloss accept --policy` (82 links) then `gloss accept --all` (7). With v0.1.0 the 25 `scope=file` and sidecar links went stale on acceptance (C13, [F-ADOPT-8](../../lab/FINDINGS-ADOPTION.md#f-adopt-8-accepting-a-scopefile-proposal-makes-it-stale-and-it-cannot-be-re-confirmed)); the stale ledger lines were dropped and `gloss build` re-recorded them as accepted.
7. The waiver, the goldens, `gloss export --status` last.

The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them. The proposed concepts wait for the Circulation department. Every friction point is in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md).
