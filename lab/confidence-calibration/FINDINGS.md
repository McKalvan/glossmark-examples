# Findings: confidence calibration of `gloss suggest` (GlossMark v0.1.0)

## Verdict

**The Phase 2 gate is not met, by a wide margin, on either codebase.** Of 172 hand-labelled `gloss suggest` proposals on two codebases, 28.5 % carry `conf >= 0.7` and only 57.1 % of those are right as written. The PR gate (`gloss diff`) classes 15.7 % of proposals SOFT, at 85.2 % precision. The target is 80 % auto-accept at 90 % precision.

| Batch | Proposals | `conf >= 0.7` share | Precision at `>= 0.7` | SOFT share (gate) | SOFT precision |
| --- | ---: | ---: | ---: | ---: | ---: |
| clinic-booking (the coordinator's batch) | 126 | 26.2 % | 42.4 % | 9.5 % | 83.3 % |
| meterworks | 46 | 34.8 % | 87.5 % | 32.6 % | 86.7 % |
| pooled, no written `allowed:` | 172 | 28.5 % | 57.1 % | 15.7 % | 85.2 % |
| pooled, manifests as committed | 148 | 28.4 % | 59.5 % | 14.9 % | 95.5 % |

Item by item, against [HYPOTHESIS.md](HYPOTHESIS.md):

1. **Precision rises with `conf`: no.** Bands are not monotone: `conf=0.95` is right 50.0 % of the time, `0.91` 70.6 %; `0.55` 46.7 %, `0.64` 8.3 %. The `0.7-0.8` band is empty in both codebases, and only two proposals fall in `0.8-0.9` (F-CAL-1, F-CAL-5).
2. **The threshold works: no.** `conf >= 0.7` is 57.1 % precise pooled, 42.4 % on clinic-booking. Moving the threshold anywhere between 0.65 and 0.80 selects the same 49 proposals (F-CAL-5).
3. **The gate meets Phase 2: no.** SOFT is 15.7 % of proposals. Its precision is respectable (85 % to 95 %) because the gate's other conditions, not `conf`, do most of the filtering (F-CAL-1).
4. **Proposals respect the boundary: no.** `suggest --write` then `check` adds 40 warnings on the coordinator's clinic batch (34 GM503, 6 GM131). A written `allowed: [derived, ...]` makes suggest drop in-scope proposals instead (F-CAL-2).
5. **Vocabulary and file-type coverage: no.** Only four relations are ever proposed, and YAML, Markdown, JSON, Dockerfiles, shell, ERB and workflows are never scanned. 15 of the 53 markers in the reviewed clinic showcase are out of reach (F-CAL-3).
6. **Not one codebase's artefact: yes, the failure holds on both.** meterworks scores much better (87.5 % at `>= 0.7`) but still misses both gate numbers. Its Java has no package-clause matches, and its implementation concepts happen to share names with classes.

**What worked well.** The gate's extra conditions are a good filter: SOFT precision is 83 % to 96 % where `conf >= 0.7` alone gives 42 % to 88 %. Exact names are reliable: SQL tables (`represents` on `CREATE TABLE`) were right 10 of 10 times at 0.91, and models and implementation classes named after their concept were right at 0.95. Markers land above decorators, annotations and `#[test]` attributes in every language tested. Every batch is deterministic and reproduced byte for byte (`run.sh` sections 1 and 2). The labels are robust: the coordinator's independent review of the clinic batch gives the same precision at `>= 0.7` (14 of 33), with 87.3 % raw agreement and Cohen's kappa 0.72.

### Method in one paragraph

Two batches. The first is clinic-booking: `showcase/clinic-booking` with every marker line deleted, then `gloss suggest --format json`. It reproduces the coordinator's 126 proposals exactly once the reminder worker's `allowed:` line (added after that run) is removed. With the committed manifests it gives 111 (F-CAL-2). The second is meterworks: a new Java/Rust/Ruby/protobuf/SQL codebase in `meterworks/`, written with its ontology and manifests in one pass before suggest first ran, and never edited afterwards. Every proposal was labelled correct, near-miss or wrong against criteria written before any proposal was read ([HYPOTHESIS.md](HYPOTHESIS.md#labels-written-before-any-proposal-was-read)). Gate classes come from `gloss diff --base HEAD --format json` after `suggest --write` in a temp git repo. Gate shares in the tables count proposals. `gloss diff` counts links, and the two Rust `impl`-block duplicates collapse into the link of the struct above them (F-CAL-6), so `run.sh` section 4 prints 44 links for meterworks' 46 proposals. Data: [data/labels.csv](data/labels.csv) (one row per proposal: conf, band, label, reason, cause, coordinator label, gate per variant). Tables: `python3 calibrate.py`. Everything: `./run.sh`.

### Inter-rater agreement (clinic-booking, 126 proposals)

```
  raw agreement 87.3%, Cohen's kappa 0.72
  lab \ coordinator    correct near-miss     wrong
  correct                   21         1         4
  near-miss                  0         6        11
  wrong                      0         0        83
```

Every disagreement is the coordinator being stricter. Three tests I accept as `verifies` were dropped because the coordinator gave their files one `scope=file` marker instead, which suggest never proposes (F-CAL-3). One HTTP handler I accept was left unmarked. Eleven near-misses were deleted rather than retargeted. The lab's label set is the more lenient of the two, so the precision figures are an upper bound.

---

## F-CAL-1: `gloss suggest` is far from the Phase 2 gate (≥ 80 % auto-accept at ≥ 90 % precision)

**Problem.** PLAN.md's Phase 2 spec gate is "≥ 80 % auto-accept at ≥ 90 % precision"; the phasing table marks confidence calibration tooling as deferred. Measured on 172 labelled proposals from two codebases, v0.1.0 reaches 15.7 % auto-accept (SOFT) at 85.2 % precision. With the threshold alone, it reaches 28.5 % at 57.1 %. No threshold reaches 90 % precision: the best value with more than two proposals, `conf=0.91`, is 70.6 %. The 80 % share is out of reach for structural reasons too. 55 % of proposals score below the documented `--min-score` (F-CAL-7). Many correct links are HARD by design, because they change the business view or sit outside the derived allowed set. And many artifacts a reviewer marks are never proposed (F-CAL-3).

Why high-confidence proposals are wrong (pooled, `conf >= 0.7`, 21 of 49 not correct):

| Cause | Count | Example (conf) |
| --- | ---: | --- |
| Go package clause / Ruby namespace module | 6 | `package booking` → `implements clinic:Booking` (0.95) in four files, tests and fakes included |
| DTO or wire type | 4 | `apps/web/lib/types.ts` `interface Practitioner` → `represents clinic:Practitioner` (0.95), a client copy of the API model |
| Terraform resource name | 2 | `aws_db_subnet_group.booking` → `provisions clinic:Booking` (0.95); `aws_iam_role.reminders` → `provisions clinic:AppointmentReminding` (0.86, alias) |
| Core concept instead of the implementation concept that names the symbol | 2 | `CancellationWindow` constant → `implements clinic:CancellationWindow` (0.95), where `lark:CancellationPolicy` exists for it |
| Test double or fixture forced to `verifies` | 2 | `stubBooker.Book` → `verifies clinic:Booking` (0.91); fixture `booked()` → `verifies clinic:Booking` (0.91) |
| Rust `impl` block duplicating the struct's marker | 2 | `impl SpikeFilter` → `implements .SpikeFilter` (0.95), see F-CAL-6 |
| Other (port interface, server action, wrong target) | 3 | `type Booker interface` → `implements clinic:Booking` (0.91) |

Across all 126 non-correct proposals, the largest causes are stem and word collisions (19). Examples: `appointment` goes to `AppointmentReminding`, `ErrNoRows` to `NoShowRate` on the word "no", and `NewService` to `ReminderService`. Then test doubles (17), package clauses (14), wrong targets (14), SQL indexes and types (11), and repository or port types (11). The `cause` column in `data/labels.csv` has every row.

Why the conf ≥ 0.7 proposals that are HARD anyway are HARD (pooled, 22 of 49):

```
   15  business view affected: business
    6  outside the allowed set derived from the manifest
    1  business view affected: published concept
```

17 of these 22 are proposals I labelled wrong or near-miss. The gate is doing the work `conf` should do.

**Repro.**

```
cd lab/confidence-calibration && ./run.sh        # regenerates all batches and gates, then:
python3 calibrate.py
...
pooled, no written allowed: (172)
  precision by band
                n correct  near wrong  precision   lenient
  <0.5         95      10    16    69      10.5%     27.4%
  0.5-0.6      16       7     3     6      43.8%     62.5%
  0.6-0.7      12       1     3     8       8.3%     33.3%
  0.7-0.8       0       0     0     0          -         -
  0.8-0.9       2       1     0     1      50.0%     50.0%
  >=0.9        47      27     3    17      57.4%     63.8%
  all         172      46    25   101      26.7%     41.3%
...
  conf >= 0.7: 49 of 172 proposals (28.5%), precision 57.1%
  gate SOFT/AUTO (gloss diff): 27 of 172 (15.7%), precision 85.2%
  Phase 2 gate (>= 80% auto-accept at >= 90% precision): NOT MET
```

**Proposed change.** Treat the Phase 2 gate as unmet in PLAN.md until it is measured. Ship the measurement with the tool: a `gloss suggest --eval labels.csv` (or a documented script like `calibrate.py`) that prints this table from a labelled sample. Then make `conf` mean what the threshold assumes (F-CAL-5), and stop proposing the non-surfaces that cause most high-confidence errors (F-CAL-4). With F-CAL-4's filters alone, precision at `>= 0.7` rises from 57.1 % to 71.8 % on this data (the `What-if` block of `calibrate.py`). That is still short of 90 %, so the scoring change is needed too.

**Done when.** `python3 calibrate.py` on a freshly labelled batch from `./run.sh` prints `Phase 2 gate ...: MET` for both codebases. Equivalently: SOFT ≥ 80 % of proposals and ≥ 90 % of SOFT labelled correct.

## F-CAL-2: `suggest` checks only a written `allowed:` list, reads its `derived` keyword literally, and writes runs that trip GM131

**Problem.** Three defects in how suggest uses the boundary:

1. **The derived allowed set is never consulted.** In boundaries without a written `allowed:`, suggest proposes targets outside the set `gloss check` derives, so its own output fails lint with GM503 (HARD in the gate). Example: `implements clinic:AppointmentReminding` on six store methods in the booking API.
2. **A written `allowed: [derived, X]` is matched literally.** `pick()` tests each hit against the written list with `model.MatchAnyCurie(m.Allowed, ...)`, so `derived` matches nothing and the boundary shrinks to `X`. `gloss check` expands `derived` correctly; the committed clinic showcase passes check with `allowed: [derived, clinic:Appointment]`. suggest then silently drops in-scope proposals:
   - On clinic-booking's reminder worker, 15 are dropped, 5 of them correct, including `compute_noshow_report implements .NoShowReport` and the scheduler tests.
   - On meterworks' ingest service, 10 are dropped, 6 of them correct, including `decode_frame` (0.82), `SpikeFilter` (0.95) and `ReadingPublisher` (0.95).
   - The filter also substitutes a worse hit: `ReadingPublisher` becomes `represents meter:MeterReading` (0.36, wrong) because the right target was filtered out.

   This also explains why the coordinator's 126-proposal batch cannot be reproduced from the committed showcase, which gives 111.
3. **Runs are not collapsed.** suggest proposes the same marker on consecutive declarations, which GM131 flags: four `represents clinic:Appointment` in one migration, four `verifies clinic:Slot` in a test fake, six `implements clinic:AppointmentReminding` in `store/appointments.go`. MARKING.md asks for one `scope=block` marker or one on the public entry point.

**Repro.**

```
cd lab/confidence-calibration && ./run.sh       # section 3
== 3. F-CAL-2: suggest --write, then check (lint findings suggest itself introduced)
  gloss suggest: 111 markers written as @gloss? proposals; review them, then gloss check && gloss build
  clinic       6 GM131
  clinic      24 GM503
  gloss check: 0 errors, 30 warnings; 111 proposals, 0 rogues (run gloss status)
  gloss suggest: 126 markers written as @gloss? proposals; review them, then gloss check && gloss build
  clinic-na       6 GM131
  clinic-na      34 GM503
  gloss check: 0 errors, 40 warnings; 126 proposals, 0 rogues (run gloss status)
  ...
  mw-na       2 GM131
  mw-na       5 GM503
  allowed: [derived, ...] is read literally: proposals dropped by the written list
  clinic: 126 -> 111; dropped 15, e.g. ['run_noshow_report implements .NoShowReport 0.45', ...]
  mw: 46 -> 37; dropped 10, e.g. ['DecodeError implements .FrameDecoder 0.45', 'decode_frame implements .FrameDecoder 0.82', 'SpikeFilter implements .SpikeFilter 0.95']
```

Individual warnings from a clinic copy after `suggest --write` (`clinic` is the showcase with markers stripped):

```
services/booking-api/internal/store/appointments.go:12: warning: implements clinic:AppointmentReminding is repeated on 6 consecutive declarations (lines 12-43); one marker with scope=block above the run, or one on the public entry point, says the same with one edge [GM131]
infra/terraform/database.tf:1: warning: provisions clinic:Booking is outside the allowed set derived from infra/.gloss.yaml (HARD gate); declare the concept there, or write allowed: to widen it (gloss check --explain shows the set) [GM503]
```

**Proposed change.** In `pick()`, test candidates against the effective allowed set `gloss check --explain` prints, with `derived` expanded, for every boundary. Use one function for check and suggest so they cannot disagree. After choosing proposals, collapse a run of three or more identical proposals in one file into one `scope=block` proposal above the run, or one on the enclosing exported symbol.

**Done when.** `./run.sh` section 3 prints no GM503 and no GM131 lines for any variant. For the `derived` defect: with `allowed: [derived, X]` written, suggest emits exactly the proposals it emits with that line removed, minus those `gloss check` would flag GM503. Equivalently, its output does not change when `derived` is replaced by the list `gloss check --explain` prints for that boundary.

## F-CAL-3: relations, scopes and file types `suggest` never proposes

**Problem.** `relation()` in `internal/suggest/suggest.go` returns only `verifies` (test path or `.feature`), `represents` (SQL, proto, or a type whose concept is an entity, event, measure or resource), `provisions` (a Terraform `resource`) and `implements`. `codeExts` limits the scan to source files. As a result, suggest never proposes:

- **Relations:** `presents` and `hosts` (pages and shells; pages get `implements`, which fits only when a page concept exists), `configures`, `deploys`, `documents`, `publishes-value`, and the flow relations `consumes`, `produces`, `publishes`, `subscribes`. The Python `AppointmentEvent` the worker reads became `represents clinic:Appointment`, and meterworks' Kafka `ReadingListener` became `represents meter:MeterReading`.
- **Scopes:** never `scope=file` or `scope=block`. The coordinator marked whole test files with one `scope=file`, which is why three per-test proposals I accepted were dropped (see the agreement section).
- **File types:** `.yaml`/`.yml` (Kubernetes manifests, workflows, app config), `.md`, `.json`, `Dockerfile`, `.sh`, `.erb` and `.ru`. `gloss build` reads markers in all of these (the corpus has `deploy.yml`, `agent.md`, `Dockerfile`, `example.sh`, `config.json.gloss`), and the clinic showcase carries 11 markers in YAML and Markdown.

Correction to the earlier adoption note (ADOPTION-LOG C10): `provisions` **is** proposed, on Terraform `resource` blocks. clinic-booking got 5. None was correct, because the target is chosen by the resource's local name (`aws_db_instance.booking` → `clinic:Booking`, not `lark:BookingDatabase`). Two were near-misses.

Measured reach: the reviewed clinic showcase carries 53 markers. 15 of them (28 %) use a relation or file type suggest cannot produce: `deploys` 4, `documents` 4, `configures` 3, `consumes` 1, `publishes-value` 1, `hosts` 1, `presents` 1. Across 172 proposals in both codebases, the relations are `implements` 82, `represents` 50, `verifies` 36, `provisions` 5. File types are only `go`, `sql`, `java`, `py`, `rs`, `tsx`, `ts`, `tf`, `rb` and `proto`. Both codebases contain YAML, Markdown and a workflow; meterworks names its Deployment `billing` and its runbook describes the invoice run, but neither got a proposal.

**Repro.**

```
cd showcase/clinic-booking
grep -rhoE "@gloss\??\s+\S+" --exclude-dir=.glossmark --exclude-dir=ontology --exclude=.gloss.yaml \
  --exclude='expected-*' --exclude=README.md --exclude-dir=demo . | sed -E 's/@gloss\??\s+//' | sort | uniq -c | sort -rn
#  17 implements   9 verifies   9 represents   4 documents   4 deploys   3 provisions
#   3 configures   1 publishes-value   1 presents   1 hosts   1 consumes
python3 -c "import csv,collections; R=list(csv.DictReader(open('lab/confidence-calibration/data/labels.csv'))); \
  print(collections.Counter(r['relation'] for r in R))"      # from the repo root
# Counter({'implements': 82, 'represents': 50, 'verifies': 36, 'provisions': 5})
```

**Proposed change.** Extend `relation()` and the scan, one rule at a time, each with its own precision check:

- A page file under a boundary that `presents` a concept gets `presents`; a layout or shell gets `hosts`.
- A Kubernetes `Deployment`/`CronJob` gets `deploys` the system-type its manifest boundary realizes. A `ConfigMap` key that equals a published value's setting name gets `configures`.
- A Markdown heading that names a concept gets `documents`.
- A type that a message-listener annotation or a queue consumer reads gets `consumes`/`subscribes`.
- A test file whose tests all point at one concept gets one `scope=file` `verifies`.

Until then, say in `gloss suggest -h` and MARKING.md which relations and file types suggest covers, so adopters know what remains to write by hand.

**Done when.** On a marker-stripped copy of `showcase/clinic-booking`, `gloss suggest --format json` contains at least one proposal for each of `presents`, `hosts`, `deploys`, `configures`, `documents` and `consumes`, and at least one in a `.yaml` and one in a `.md` file. Or, failing that, `gloss suggest -h` lists the relations and file types it covers.

## F-CAL-4: `suggest` proposes declarations that are never a public surface

**Problem.** MARKING.md says to mark "the handler, the pipeline entry point, the model, the table, the test file", never helpers. suggest proposes every declaration its detector finds whose name matches. The detector also finds:

- **Go package clauses** (10 proposals, all wrong, six at 0.95). `package booking` matches `clinic:Booking` exactly in every file of the package, tests included. **Ruby namespace modules** (`module Portal` in four files, 0.64) behave the same.
- **Declarations in test files that are not tests.** `IsTestPath` turns every declaration into `verifies`, so fakes, stubs and fixture builders are proposed: 17 proposals, all wrong. Examples: `fakeRepo.GetSlot`, `stubBooker.Book` (0.91), `booked()` (0.91), `InMemoryInvoiceRepository`, and a Rust `fn frame()` helper.
- **Rust `impl` blocks**, proposed with the same marker as the struct above them (2 duplicates at 0.95, which also trigger F-CAL-6).
- **SQL indexes and enum types** next to their table (11 proposals, all wrong). One of clinic-booking's six GM131 runs is a table with its type and two indexes.
- **Private Rust functions.** `private()` only knows a leading `_`, `main` and `init`, so the non-`pub` `fn register_for` was proposed. Go's unexported functions are proposed the same way (`scanAppointment`, `newTestService`).

The first four kinds are 44 of the 126 non-correct proposals.

**Repro.** `python3 lab/confidence-calibration/calibrate.py`, last blocks:

```
All non-correct proposals by cause (pooled, no written allowed:)
   19  stem-or-word-collision
   17  test-double
   14  wrong-target
   14  package-clause
   ...
   11  part-of-table
    2  duplicate-impl-block
What-if: suggest skipped package/module clauses, non-test declarations in test files,
Rust impl blocks and SQL indexes/types (causes a syntactic filter can see)
  128 proposals left; conf >= 0.7: 39, precision 71.8%
```

Rows with `cause` = `package-clause`, `test-double`, `duplicate-impl-block` or `part-of-table` in `data/labels.csv` are the instances.

**Proposed change.** In `suggest.Run`, skip:

- package and namespace declarations (Go `package`, Ruby `module`, Java `package`, Rust `mod`);
- in test paths, every declaration that is not a test, using per-language test patterns (`Test*`, `test_*`, `#[test]`, `@Test`, `it`/`describe`);
- Rust `impl` blocks, which carry no new symbol;
- SQL `CREATE INDEX` and `CREATE TYPE` when a `CREATE TABLE` in the same file was proposed;
- language-private declarations (Go lower-case, Rust without `pub`, Java `private`, TypeScript not exported).

**Done when.** On the two batches regenerated by `./run.sh`, no proposal has a `cause` of `package-clause`, `test-double`, `duplicate-impl-block` or `part-of-table` after relabelling. Mechanically: `gloss suggest --format json` on the stripped clinic copy contains no proposal whose `symbol` is a package name (`booking`, `httpapi`, `outbox`, `store`) and none in `fake_test.go`.

## F-CAL-5: `conf` is a lexical score, highest where the match says least, and too coarse to calibrate

**Problem.** `conf = min(0.95, round(score/110, 2))`, where `score` is the best hit's search score (`internal/mcp/search.go`). Nothing else enters it:

- not the declaration's kind or the file's role (test, fake, client, migration index);
- not the margin to the second-best concept;
- not whether an implementation concept's doc names the symbol.

A one-word symbol that equals a concept name after stemming scores 100 to 110, which gives 0.91 to 0.95. The examples are `package booking`, `Book`, `booked`, the client DTO `Practitioner`, and `aws_db_subnet_group.booking`. So the top band holds both the most reliable proposals (tables, models) and the least reliable (package clauses, stubs, resource names): `0.95` is 50.0 % correct, below `0.91` at 70.6 %.

Ties and near-ties go to the core tier. `Service.Book` → `clinic:Booking` (0.91) wins although `lark:BookingHandler`'s doc reads "Service.Book: checks the slot and overlaps...". The same happens for `Service.Cancel`, `plan_reminders`, `ReadingEstimator`, `DunningScheduler` and the `CancellationWindow` constant: six near-misses, two at 0.91 to 0.95.

`conf` also takes only ten values in 172 proposals: 0.36, 0.41, 0.45, 0.55, 0.59, 0.64, 0.82, 0.86, 0.91 and 0.95. Nothing falls between 0.64 and 0.82. QUICKSTART suggests "calibrate `soft-conf-threshold` from agreement", but there is nothing to calibrate: every threshold from 0.65 to 0.80 selects the same proposals. ADVANCED.md calls `conf=` "an agent's confidence", while suggest's `conf` is a rescaled string-match score.

**Repro.**

```
python3 lab/confidence-calibration/calibrate.py | sed -n '/Threshold sweep/,/=====/p'
  conf >= 0.65:   49 ( 28.5%), precision  57.1%
  conf >= 0.70:   49 ( 28.5%), precision  57.1%
  conf >= 0.75:   49 ( 28.5%), precision  57.1%
  conf >= 0.80:   49 ( 28.5%), precision  57.1%
  conf >= 0.85:   48 ( 27.9%), precision  56.2%
  conf >= 0.90:   47 ( 27.3%), precision  57.4%
  conf >= 0.95:   30 ( 17.4%), precision  50.0%
```

Per-value table: the `precision by exact conf value` block of the same output. The core-over-implementation near-misses are the rows with `cause` = `core-instead-of-impl`.

**Proposed change.**

- Compute `conf` from features, not the raw score: the declaration's role (exported type or function, test function, other), the margin over the second hit, whether the symbol's full name (`Service.Book`) appears in a concept's doc, and an exact match to an implementation concept over a stemmed match to a core one.
- Fit the mapping from features to probability on a labelled set like `data/labels.csv`, and ship the fitted table with a test that the bands stay monotone.
- Until then, write `score=` instead of `conf=` on suggest's output, or document that suggest's `conf` is uncalibrated and should not drive SOFT.

**Done when.** On a fresh labelled batch, precision is non-decreasing across the bands in `calibrate.py`, and `conf >= 0.9` is at least 90 % correct. A threshold sweep from 0.5 to 0.95 changes the selected set at least at every 0.1 step.

## F-CAL-6: two identical proposals on one symbol share a marker id; accept rewrites one and the other is stuck as proposed

**Problem.** In Rust, suggest proposes the same marker above a struct and above its `impl` block (F-CAL-4). Both markers anchor to the same symbol and get the same marker id. `gloss build` keeps one artifact, `gloss diff` shows one change, and `gloss status` shows one id. `gloss accept <id>` rewrites only the first line. The second `@gloss?` line stays, `gloss status` still lists the id as proposed, and a second `gloss accept <id>` refuses with "is not proposed". There is no command that clears it; a reviewer must edit the file. It is not specific to Rust: two identical `@gloss?` lines stacked above one Go type behave the same, and `gloss check` reports nothing for either. The Rust `impl` pattern is just where suggest produces it.

**Repro.**

```
cd lab/confidence-calibration && ./run.sh       # section 5 (ingest allowed: removed, suggest --write, build)
== 5. F-CAL-6: two identical proposals on one Rust type (struct + impl block)
  marker id: m-921c9809b3
  accept services/ingest/src/filter.rs:20 implements .SpikeFilter [SOFT]
  gloss accept: 1 link accepted by agent:claude-code
  filter.rs:20:// @gloss implements .SpikeFilter conf=0.95
  filter.rs:26:// @gloss? implements .SpikeFilter conf=0.95
  still proposed:   m-921c9809b3  services/ingest/src/filter.rs  implements .SpikeFilter conf=0.95  by agent:claude-code  [SOFT]
  services/ingest/src/filter.rs:20: m-921c9809b3 is not proposed; nothing to accept
  gloss accept: 0 links accepted by agent:claude-code
```

The same with Go, on a marker-stripped clinic copy, after putting two `// @gloss? implements .OutboxRelay conf=0.9` lines above `type Relay struct` in `services/booking-api/internal/outbox/relay.go`, then `build`, `check`, `status`, `accept` twice:

```
gloss build: 87 files scanned, 2 markers, 48 nodes (33 concepts, 7 boundaries, 1 artifacts), ...
(gloss check: no line for relay.go)
gloss accept: 1 link accepted by agent:claude-code
12:// @gloss implements .OutboxRelay conf=0.9
13:// @gloss? implements .OutboxRelay conf=0.9
  m-58ba98818e  services/booking-api/internal/outbox/relay.go  implements .OutboxRelay conf=0.90  by agent:claude-code  [SOFT]
services/booking-api/internal/outbox/relay.go:12: m-58ba98818e is not proposed; nothing to accept
```

**Proposed change.** Two parts:

- `gloss check` reports a duplicate marker (same relation, target and anchor symbol) as a warning that points at both lines.
- `gloss accept <id>` rewrites every `@gloss?` line that carries the id, and `gloss status` derives "proposed" from the lines in the file rather than the first ledger entry.

**Done when.** In the repro, after one `gloss accept m-921c9809b3`, `grep -c '@gloss?' services/ingest/src/filter.rs` prints 0 and `gloss status` no longer lists the id. Alternatively, `gloss check` flags line 26 before accept.

## F-CAL-7: `--min-score` is not the lowest score suggest emits; more than half the proposals fall below it

**Problem.** `gloss suggest -h` says `-min-score int  lowest search score that becomes a proposal (default 60)`. The code keeps any hit with `score >= min-score - 20` and at least 40. The default therefore emits scores down to 40 (`conf=0.36`). 95 of 172 proposals (55 %) score below 60, and only 10 of them (10.5 %) are correct. Setting `--min-score 80` to get "60 and up" is undiscoverable.

**Repro.** On the marker-stripped clinic copy with the reminder worker's `allowed:` removed (run.sh section 1 builds it):

```
gloss suggest --format json --min-score 60   # 126 proposals, lowest conf 0.36 (score ~40)
gloss suggest --format json --min-score 70   # 124 proposals, lowest conf 0.45 (score ~50)
gloss suggest --format json --min-score 80   # 51 proposals,  lowest conf 0.55 (score ~61)
gloss suggest --format json --min-score 100  # 33 proposals,  lowest conf 0.86 (score ~95)
```

**Proposed change.** Make `--min-score` the floor it says it is, and keep the docstring fallback's 20-point penalty inside the score rather than in the threshold. Or rename the flag and document the `-20` slack. Given the 10.5 % precision below 60, consider a default floor of 60.

**Done when.** `gloss suggest --format json --min-score 60` emits no proposal with `conf < 0.55`.
