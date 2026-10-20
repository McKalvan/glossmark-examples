# Findings: version evolution

All output below comes from [run.sh](run.sh) with the v0.1.0 binary. Its full output is committed as [TRANSCRIPT.md](TRANSCRIPT.md). `./run.sh` regenerates the transcript in a temporary git repository and prints `ok` when it matches; it did on eight consecutive runs. The setup and the twelve expectations are in [HYPOTHESIS.md](HYPOTHESIS.md).

## Verdict

v0.1.0 gets the hard part right. `gloss diff` classifies every change in this experiment:

- a doc change is PATCH;
- an addition is MINOR;
- a removal, a retype, an is-a change and a withdrawn `published:` are each MAJOR.

The `Version` line marks a missing or undersized bump with ✗. GM107 catches "upstream forgot to bump" in every importer, with a message that says exactly that. Deprecation with `replaced-by` warns importers in markers, manifests and ontology files, and names the replacement. GM105, GM106, GM108 and GM109 each fire on their case, and the migration path for an importer is clean.

Where it falls short is everything between the owner and the importers. A forgotten bump passes the owner's gate and turns every importer red. `gloss lock` records versions the range forbids. A namespace has two version fields that disagree silently. The published-only rule for implementation imports is not enforced. `landscape`, the one cross-repository view, knows nothing about versions.

| # | Expectation | Met? | Evidence |
| --- | --- | --- | --- |
| 1 | Classification of each kind of change | **Yes**, except that deprecation is PATCH (semver.org says MINOR) | Steps 1, 2, 2a, 3, 3a to 3d, 4. [F-VER-9](#f-ver-9-deprecation-alone-is-classified-patch) |
| 2 | Missing or undersized bump fails the owner's gate | **No** | Step 1a: `gate SOFT`, exit 0. Steps 3a to 3d: the undersized bump is a `[SOFT]` line; exit 1 comes from the MAJOR change itself. [F-VER-1](#f-ver-1-a-forgotten-bump-passes-the-owners-gate-and-breaks-every-importer) |
| 3 | GM107 catches content change under the same version | **Yes** | Step 1a, all three importers |
| 4 | GM106 on out-of-range; lock never records a forbidden version | **Half** | GM106 fires (steps 2 to 4). `gloss lock` writes `2.0.0 (~1.0.0)` and `none (1.x)` with exit 0. [F-VER-2](#f-ver-2-gloss-lock-records-a-version-the-range-forbids-and-the-lock-does-not-pin) |
| 5 | One source of truth for the version | **No** | Steps 1b, 1c. [F-VER-3](#f-ver-3-a-namespace-has-two-version-fields-and-nothing-checks-that-they-agree) |
| 6 | Deprecation warns importers before removal | **Yes** in `check` (GM222 in all three places); **no** in `landscape` | Step 3. [F-VER-5](#f-ver-5-landscape-is-blind-to-versions-ranges-locks-and-deprecations) |
| 7 | Removal breaks loudly everywhere it is referenced | **Partly** | `check`: GM215 on all four references. `drift` and `landscape`: only the two marker references. [F-VER-6](#f-ver-6-drift-and-landscape-report-dangling-references-from-markers-only) |
| 8 | Published-only rule for implementation imports | **No** | Steps 3d, 3e. [F-VER-4](#f-ver-4-the-published-only-rule-for-imported-implementation-concepts-is-not-enforced) |
| 9 | Landscape shows version skew | **No** | Step 4. [F-VER-5](#f-ver-5-landscape-is-blind-to-versions-ranges-locks-and-deprecations) |
| 10 | GM105, GM108, GM109 | **Yes** | Steps 1c, 4a |
| 11 | A retype is explained where it bites | **No** | Step 4, analytics. [F-VER-7](#f-ver-7-a-retype-surfaces-downstream-as-an-unexplained-gap) |
| 12 | Determinism | **Mostly** | The lockfile is stable, but `gloss lock`'s stdout order is not. [F-VER-10](#f-ver-10-gloss-lock-prints-namespaces-in-random-order) |

## Step-by-step summary

One row per release or failure case. "check" is the importer's `gloss check` before it re-locks. "lock" is what `gloss lock` did. The lock is kept only when the post-lock check has no GM106, so an importer out of range keeps its old lock. Full output is in [TRANSCRIPT.md](TRANSCRIPT.md).

| Step | Upstream `gloss diff --base HEAD` | billing `~1.0.0` | outage-map `^1.0` (+ `mc 1.x`) | analytics `>=1.0 <3.0` | `gloss landscape` |
| --- | --- | --- | --- | --- | --- |
| 0. 1.0.0 baseline | | check clean | check clean | check clean | exit 0; one context-map edge (outage-map to meter-core via `mc:ReadingFeed`) |
| 1. 1.0.1 PATCH (doc on a published concept) | gate HARD (published doc); `requires PATCH ✓` | GM107; lock 1.0.1; clean | same | same | exit 0 |
| 1a. doc change, no bump | **gate SOFT, exit 0**; `requires PATCH ✗` | GM107 "content changed ... same version number" | same | same | |
| 1b. bump only in `glossmark.yaml` | upstream `check` clean; diff reads the file: `1.0.1 → 1.0.1 ✗` | | GM107 same-version | | |
| 1c. version only in `glossmark.yaml` | upstream `check` clean; diff falls back to `owns`: `1.0.1 → 1.0.2 ✓` | | GM105 + GM107 "resolved none" | | |
| 2. 1.1.0 MINOR (add) | gate HARD; `requires MINOR ✓` | GM106 + GM107; **lock writes 1.1.0, exit 0**; reverted | GM107; lock 1.1.0; clean | GM107; lock 1.1.0; clean | exit 0 |
| 2a. deprecation only, 1.1.1 | gate HARD; `requires PATCH ✓` | | | | |
| 3. 1.2.0 MINOR (add, deprecate Outage) | gate HARD; `requires MINOR ✓` | GM106 + GM107; lock 1.2.0, reverted | GM107 + **GM222 x3**; lock 1.2.0; GM222 x3 remain | GM107 + GM222; lock; GM222 | exit 0; **no deprecation mentioned** |
| 3a. removal declared 1.3.0 | gate HARD; `requires MAJOR ✗` as a **SOFT** line | | in range: GM107 + GM215 x3 | in range: GM107 + GM215 + GM501 | |
| 3b. retype declared 1.3.0 | gate HARD; `requires MAJOR ✗` (SOFT line) | | | GM107 only | |
| 3c. is-a change declared 1.3.0 | gate HARD; `requires MAJOR ✗` (SOFT line) | | | | |
| 3d. `mc:ReadingFeed` unpublished, mc 1.1.0 | gate HARD; `requires MAJOR ✗` (SOFT line) | | GM107; lock 1.1.0; **clean** | | exit 0; **edge via the unpublished concept still drawn** |
| 3e. reference a never-published `mc:` concept | | | **clean** | | |
| 4. 2.0.0 MAJOR (remove, retype, is-a) | gate HARD; `requires MAJOR ✓`; removal says "prefer deprecated" | GM106 + GM107; lock writes 2.0.0, exit 0; reverted; drift clean | GM106 + GM107 + GM215 x3; lock reverted; **drift: 1 dangling** | GM107 + GM215 + GM501; lock 2.0.0; drift: dangling + **gap on `grid:Tariff`** | exit 1; 2 dangling, 1 gap; **no version skew reported** |
| 4a. lock deleted / `format: 99` / mc unversioned | | GM108 / GM109 | GM105 + GM107; **lock writes `mc: none (1.x)`, exit 0** | | |
| 5. outage-map migrates to `^2.0` | | | lock 2.0.0; check clean; drift clean | | exit 1 (analytics' dangling remains) |

## F-VER-1: A forgotten bump passes the owner's gate and breaks every importer

**Problem.** VERSIONING.md says "A missing bump is reported as SOFT". In practice the owner's PR gate (`gloss diff`, default `--fail-on HARD`, which the GitHub Action uses) passes a release that changed content and kept the version. On the next run, every importer that locked the old content fails `gloss check` with GM107, an error. The owner is green and every importer is red, and the only fix available to an importer is `gloss lock`, which accepts the unversioned change. An undersized bump has the same SOFT severity. A MINOR declared for a removal, a retype, an is-a change or a withdrawn `published:` is a `[SOFT]` line, and the diff exits 1 only because the MAJOR change is HARD on its own. If the owner approves the HARD gate, the undersized version ships, and every importer on `^1.0` takes the breaking change inside its range.

**Repro.** `lab/version-evolution/run.sh`, transcript steps 1a and 3a. The doc change on `grid:Customer` with `version:` left at 1.0.1:

```text
$ (cd meter-core && gloss diff --base HEAD)
Ontology impact — meter-core   base HEAD   gate SOFT
! namespace grid: changes require a PATCH bump but version went 1.0.1 → 1.0.1 (none)   ontology/grid.gloss.yaml     [SOFT]
! grid:Customer label/doc                                      ontology/grid.gloss.yaml:6   [SOFT]
...
Version grid: 1.0.1 → 1.0.1 (requires PATCH) ✗
[exit 0]

$ (cd billing && gloss check)
glossmark.lock:1: error: imports.grid: ontology content changed since it was locked at 1.0.1 (same version number); the upstream should bump its version. Run gloss lock to accept [GM107]
[exit 1]
```

The same error appears in outage-map and analytics. Step 3a, `grid:Outage` removed and `version: 1.3.0`:

```text
! namespace grid: changes require a MAJOR bump but version went 1.2.0 → 1.3.0 (MINOR)   ontology/grid.gloss.yaml      [SOFT]
Version grid: 1.2.0 → 1.3.0 (requires MAJOR) ✗
```

outage-map (`^1.0`) then gets no GM106, only GM107 and three dangling references.

**Proposed change.** Gate a missing or undersized bump on an owned namespace as HARD, as the other changes in the namespace are; importers' ranges rely on it. Alternatively, give it its own gate class that the Action fails on by default. Update the VERSIONING.md sentence to match.

**Done when.** Step 1a's `gloss diff --base HEAD` exits 1 with `gate HARD`, and step 3a's undersized-bump line is tagged `[HARD]`.

## F-VER-2: gloss lock records a version the range forbids, and the lock does not pin

**Problem.** GM107's message tells an importer to "review the upstream change, then run gloss lock". `gloss lock` writes whatever it resolves and exits 0, even when the range forbids it or the upstream has no version. Following the instruction turns GM106 + GM107 into GM106 alone, and the committed lock then claims `2.0.0` under `~1.0.0`.

Separately, the lock is a tripwire rather than a pin. With local-path imports, `build`, `drift` and `landscape` always read the upstream file on disk. billing, locked at 1.0.1 under `~1.0.0`, is evaluated against 2.0.0 and its drift is clean with exit 0. `build` exits 1 on GM106 but still writes the graph. The importer cannot stay on the version it chose; its only options are to fail or to move.

**Repro.** Transcript steps 2, 4 and 4a:

```text
$ (cd billing && gloss lock)
gloss lock: grid: 1.1.0 (~1.0.0) sha256:480b932b1f35
gloss lock: written glossmark.lock; commit it
[exit 0]

$ (cd outage-map && gloss lock)        # mc.gloss.yaml has no version:
gloss lock: grid: 2.0.0 (^1.0) sha256:4c2f1d106137
gloss lock: mc: none (1.x) sha256:0093eb1707d2
gloss lock: written glossmark.lock; commit it
[exit 0]
```

Build and drift against an out-of-range upstream (copy `meter-core` and `billing`, set `version: 2.0.0` in `grid.gloss.yaml`):

```text
$ (cd billing && gloss build)
glossmark.yaml:1: error: imports.grid: requires ~1.0.0 but the resolved ontology is 2.0.0 (../meter-core/ontology/grid.gloss.yaml) [GM106]
...
gloss build: 3 files scanned, 3 markers, 17 nodes ... → .glossmark/graph.jsonl
[exit 1]
$ (cd billing && gloss drift)
[exit 0]
```

**Proposed change.**

1. `gloss lock` refuses with exit 1 when a resolved version is outside its range or absent, and leaves the lock untouched. Add `--allow-out-of-range` for a deliberate override.
2. `gloss lock` copies each locked ontology into `.glossmark/imports/<prefix>@<version>.gloss.yaml`, and every command resolves the import from that copy while its hash matches the lock. `gloss check` then warns that a newer upstream is available, and `gloss lock --update` moves forward. This makes a lock a pin for local paths, and the git fetcher can reuse it.

**Done when.** Step 2's `gloss lock` in billing exits 1 and leaves `glossmark.lock` unchanged. With the vendored copy, billing's `gloss check` at grid 2.0.0 warns "2.0.0 available, outside ~1.0.0" and resolves `grid:` from the 1.0.1 copy.

## F-VER-3: A namespace has two version fields, and nothing checks that they agree

**Problem.** VERSIONING.md says a namespace's version lives "in `glossmark.yaml` (`owns.<prefix>.version`) or in the ontology file", and FILE-FORMATS.md's example sets both. They behave differently:

- `gloss diff` reads the ontology file and falls back to `owns` only when the file has no `version:`.
- Importers read only the ontology file.
- `gloss check` in the owner never compares the two.

After transcript step 1, `owns.grid.version` still says 1.0.0 while the file says 1.0.1, and nothing reports it. A maintainer who bumps `glossmark.yaml` sees a passing `check`. Then either `diff` says the bump is missing or, if the file has no version, `diff` says the bump is right while every importer is told the namespace has no version.

**Repro.** Transcript steps 1b and 1c:

```text
# 1b: owns 1.0.2, file 1.0.1
$ (cd meter-core && gloss check)
gloss check: 0 errors, 0 warnings
$ (cd meter-core && gloss diff --base HEAD)
Version grid: 1.0.1 → 1.0.1 (requires PATCH) ✗

# 1c: owns 1.0.2, file has no version:
$ (cd meter-core && gloss check)
gloss check: 0 errors, 0 warnings
$ (cd meter-core && gloss diff --base HEAD)
Version grid: 1.0.1 → 1.0.2 (requires PATCH) ✓
$ (cd outage-map && gloss check)
glossmark.yaml:1: warning: imports.grid: requires ^1.0 but the imported ontology declares no version; add version: to its grid.gloss.yaml [GM105]
glossmark.lock:1: error: imports.grid: locked at 1.0.1 but resolved none; review the upstream change, then run gloss lock [GM107]
```

**Proposed change.** Make the ontology file the single source, because it is the file importers resolve. In the owner, `gloss check` errors when `owns.<prefix>.version` differs from the file's `version:`, and warns when the version is only in `glossmark.yaml`. `diff` stops falling back to `owns`. Fix VERSIONING.md and FILE-FORMATS.md to match.

**Done when.** `gloss check` in meter-core reports an error at step 1b and a warning at step 1c, and step 1c's `diff` prints the same version an importer sees.

## F-VER-4: The published-only rule for imported implementation concepts is not enforced

**Problem.** FILE-FORMATS.md: "Only **published** concepts of an imported implementation namespace are referenceable." In v0.1.0 an importer can reference any concept of an imported implementation namespace. When the owner withdraws `published:` from a concept, the owner's `diff` correctly calls it MAJOR, but an importer that still subscribes to it gets only GM107. After `gloss lock` it is clean, and `landscape` still draws the context-map edge through the now-internal concept. This is the seam the two-tier model rests on, and nothing guards it. [F-SPLIT-3](../monolith-decomposition/FINDINGS.md#f-split-3-an-imported-implementation-namespace-is-typed-core-unless-the-import-says-tier-which-is-undocumented) found why: without `tier: implementation` on the import entry or in the upstream file, the namespace is typed core and GM230 never applies.

**Repro.** Transcript step 3d (`mc:ReadingFeed` loses `published:`, `mc` 1.1.0) and step 3e (outage-map references `mc:ReadingIngestor`, which was never published):

```text
# 3d, after gloss lock
$ (cd outage-map && gloss check)
...
gloss check: 0 errors, 3 warnings        # only GM222 deprecation warnings
$ (cd . && gloss landscape meter-core billing outage-map analytics)
Context map (publishes → subscribes, produces → consumes across boundaries)
  omapb:outage-map → mcb:meter-core via mc:ReadingFeed

# 3e
$ (cd outage-map && gloss check)
gloss check: 0 errors, 3 warnings
```

Minimal repro on the committed state:

```sh
sed -i 's/mc:ReadingFeed/mc:ReadingIngestor/g' outage-map/ontology/omap.gloss.yaml outage-map/.gloss.yaml
```

`gloss check` then prints `0 errors, 0 warnings`.

**Proposed change.** `gloss check` errors on any reference from markers, manifests or the importer's ontology to an imported implementation concept without `published:`, and suggests the core concept it realizes. `landscape` draws no edge through an unpublished concept and reports it.

**Done when.** Step 3e's `gloss check` errors on `ontology/omap.gloss.yaml:6` and `.gloss.yaml:1` naming `mc:ReadingIngestor`, and step 3d's post-lock check does the same for `mc:ReadingFeed`.

## F-VER-5: landscape is blind to versions, ranges, locks and deprecations

**Problem.** `gloss landscape` is the one cross-repository view, and the place an owner would ask "who still uses this?" before a MAJOR release. It reports none of the version state that `check` knows in each repository:

- importers outside their range (GM106);
- locks behind the resolved version (GM107);
- references to deprecated concepts (GM222);
- the version each repository resolved.

At 2.0.0, billing (`~1.0.0`) and outage-map (`^1.0`) are both out of range, and the landscape says nothing about it. At 1.2.0, four references to the deprecated `grid:Outage` exist across two repositories, and the landscape is clean with exit 0. The JSON output has `context_map`, `drift`, `repos` (names only) and `stats`, with no version field.

**Repro.** Transcript step 3 and step 4 landscape blocks:

```text
# step 3, grid 1.2.0, Outage deprecated and referenced four times
...
· Orphan concepts (no artifacts)
  grid:PeakDemand: ...
  grid:SupplyInterruption: ...
[exit 0]

# step 4, grid 2.0.0, billing ~1.0.0 and outage-map ^1.0 out of range
gloss landscape: 2 failing findings (violation,dangling)    # the two dangling markers; no range finding
```

**Proposed change.** Add an "Imports" section with one row per importer and namespace: range, locked version, resolved version and status (`ok`, `lock behind`, `out of range`, `content changed without bump`). Add a "Deprecated in use" section listing references with their `replaced-by`. Add the finding kinds `out-of-range` and `deprecated-use` for `--fail-on`, and put versions in the JSON `repos` entries.

**Done when.** Step 4's landscape lists billing and outage-map as `out of range`, and step 3's landscape lists the four `grid:Outage` references under "Deprecated in use".

## F-VER-6: drift and landscape report dangling references from markers only

**Problem.** When `grid:Outage` is removed, outage-map references it from three places: a marker, its manifest (`subscribes:`) and its own ontology (`OutageLayer.subscribes`). `gloss check` reports all three as GM215, but `gloss drift` and `gloss landscape` report only the marker. analytics' `allowed:` entry gets GM501 in `check` and nothing in `drift`. Once the marker is fixed, the manifest and ontology references stay dangling with drift green.

**Repro.** Transcript step 4, outage-map:

```text
$ (cd outage-map && gloss check)
.gloss.yaml:1: error: dangling reference: grid:Outage does not exist [GM215]
ontology/omap.gloss.yaml:6: error: dangling reference: grid:Outage does not exist [GM215]
src/outages.ts:1: error: dangling reference: grid:Outage does not exist [GM215]
$ (cd outage-map && gloss drift --fail-on dangling,violation,gap)
! Dangling references
  src/outages.ts:1 represents grid:Outage: concept does not exist (write grid:NEW:Outage with @gloss? to propose it)  [src/outages.ts:1]
gloss drift: 1 failing finding (dangling,violation,gap)
```

With `grid:Outage` removed upstream and only the marker in `src/outages.ts` retargeted to an existing concept, `drift --fail-on dangling,violation,gap` exits 0. `gloss check` still reports `.gloss.yaml:1` and `ontology/omap.gloss.yaml:6` as GM215.

**Proposed change.** Emit a `dangling` drift finding for every unresolved concept reference in manifests (all relation keys and `allowed:`) and in the workspace's own ontology files, with the file and line `check` already has.

**Done when.** Step 4's outage-map drift lists three dangling references, and landscape lists four across outage-map and analytics, plus analytics' `allowed:` entry.

## F-VER-7: A retype surfaces downstream as an unexplained gap

**Problem.** At 2.0.0, `grid:Tariff` changes from `entity` to `constraint`. analytics declares `holds: [grid:Tariff]` and has `-- @gloss represents grid:Tariff` on `models/tariff_bands.sql`. `represents` lifts to `holds` only on an entity, so analytics gets a gap saying nothing represents it. That message is false on its face, because the marker is there. Neither `check` nor `drift` mentions that the kind changed, and the importer never sees the owner's diff, which does name the retype.

**Repro.** Transcript step 4, analytics:

```text
○ Gaps (declared, not implemented)
  anab:analytics declares holds grid:Tariff but nothing under it represents it: intended capability not implemented, or the declaration is wrong  [.gloss.yaml:1]
```

**Proposed change.** When a declared relation cannot lift because the concept's kind does not allow it (`holds` on a non-entity, `publishes` on a non-event), report it as a lint in `check`, for example `holds grid:Tariff: grid:Tariff is a constraint; holds takes entities`. Reword the drift gap to name the artifacts whose links did not lift. When the lock knows the previous kind, say "retyped from entity in 2.0.0".

**Done when.** Step 4's analytics `check` reports the kind mismatch on `.gloss.yaml`, and the drift gap names `models/tariff_bands.sql`.

## F-VER-8: Removing a deprecated concept gets advice to deprecate it

**Problem.** The owner did the right thing: deprecated `grid:Outage` with `replaced-by: SupplyInterruption` in 1.2.0 and removed it in 2.0.0. The 2.0.0 diff still says `IDs are permanent, prefer deprecated: true + replaced-by:`, which reads as a reprimand for the recommended path. Nothing distinguishes a removal after a deprecation cycle from a removal out of nowhere.

**Repro.** Transcript step 4 (also step 3a):

```text
- concept grid:Outage removed; IDs are permanent, prefer deprecated: true + replaced-by:   ontology/grid.gloss.yaml:13   [HARD: edit to ontology (MAJOR)]
```

**Proposed change.** When the base already marks the concept deprecated, print `concept grid:Outage removed (deprecated since base, replaced-by grid:SupplyInterruption)`. Keep the advice for removals without a prior deprecation.

**Done when.** The step 4 and step 3a removal lines name the replacement and drop the advice.

## F-VER-9: Deprecation alone is classified PATCH

**Problem.** `gloss diff` classifies a change that only sets `deprecated: true` + `replaced-by:` as PATCH. Semantic Versioning 2.0.0, item 7, says the MINOR version "MUST be incremented if any public API functionality is marked as deprecated". A deprecation changes what importers see, since GM222 starts firing in their `check`, so a `~1.0.0` importer receives new warnings inside a patch range. VERSIONING.md's bump table does not mention deprecation. The same classification is [F-SPLIT-9](../monolith-decomposition/FINDINGS.md#f-split-9-deprecation-is-classified-patch) from the owner's side; file one issue for both.

**Repro.** Transcript step 2a:

```text
! grid:Meter deprecated false → true     ontology/grid.gloss.yaml:7   [HARD: edit to ontology]
Version grid: 1.1.0 → 1.1.1 (requires PATCH) ✓
```

**Proposed change.** Classify a new `deprecated: true` as MINOR and add the row to VERSIONING.md's bump table. If PATCH is deliberate, document it there instead.

**Done when.** Step 2a prints `requires MINOR ✗`, or VERSIONING.md lists deprecation under PATCH.

## F-VER-10: gloss lock prints namespaces in random order

**Problem.** With two imports, `gloss lock` prints its per-namespace lines in map iteration order. The file it writes is stable; stdout is not. It is cosmetic, but it breaks golden-file tests of the command, and `run.sh` has to sort those lines.

**Repro.** In a copy of `lab/version-evolution`, in `outage-map`:

```sh
for i in $(seq 60); do $GLOSS lock | head -1 | cut -c1-17; md5sum glossmark.lock; done | sort | uniq -c
```

```text
     60 ba5d57090451c66a8ecf322b8bd7ac81  glossmark.lock
     50 gloss lock: grid:
     10 gloss lock: mc: 1
```

**Proposed change.** Print namespaces sorted by prefix, as the file is.

**Done when.** The repro shows a single first line across 60 runs.

## F-VER-11: landscape prints workspace-relative paths for boundary and ontology findings

**Problem.** In `gloss landscape` output, marker findings carry the repository (`analytics/models/outage_minutes.sql:1`), but boundary and ontology findings do not (`[.gloss.yaml:1]`, `[ontology/grid.gloss.yaml:7]`). With four repositories, `.gloss.yaml:1` could be any of them.

**Repro.** Transcript step 4 landscape:

```text
  anab:analytics declares holds grid:Tariff but nothing under it represents it: ...  [.gloss.yaml:1]
  analytics/models/outage_minutes.sql:1 represents grid:Outage: concept does not exist ...  [analytics/models/outage_minutes.sql:1]
  grid:Meter: orphan concept, no artifact links to it  [ontology/grid.gloss.yaml:7]
```

**Proposed change.** Prefix every location in landscape output with its repository directory.

**Done when.** The step 4 landscape prints `[analytics/.gloss.yaml:1]` and `[meter-core/ontology/grid.gloss.yaml:7]`.

## What worked well

- **Classification is right on every MAJOR trigger.** Each of the following gives `namespace grid: MAJOR change` and `requires MAJOR`, alone or combined: a removal, a retype (`kind entity → constraint`), an is-a change (`is-a grid:Meter removed` / `is-a grid:ConnectedDevice added`), and a withdrawn `published:` on an implementation namespace.
- **GM107 has three distinct, accurate messages:**
  - `locked at X but resolved Y`;
  - `ontology content changed since it was locked at X (same version number); the upstream should bump its version`;
  - `locked at X but resolved none`.
- **GM222 covers every reference site:** marker, manifest and the importer's own ontology, with the replacement named.
- **GM105, GM106, GM108 and GM109 messages** each name the file, the range and the fix.
- **Migration is cheap.** Widening the range to `^2.0`, a three-file rename to `grid:SupplyInterruption` and one `gloss lock` gave a clean `check` and `drift` in outage-map (step 5).
- **The lockfile is deterministic**, and everything else in the transcript is byte-identical across runs.
