# Findings: deep hierarchies

All output below comes from GlossMark v0.1.0 (`gloss 0.1.0`, grammar 1). `run.sh` reproduces each excerpt. Mutations run on temporary copies, so the committed workspaces stay as described in [HYPOTHESIS.md](HYPOTHESIS.md). Paths are relative to `lab/deep-hierarchies/`.

## Verdict

The core inheritance machinery holds up at depth. Most of the hypothesis is met. The failures sit at the edges: `part-of` coverage, kinds inherited through `is-a`, cycles, and diagnostics that grow with depth.

| # | Hypothesis item | Result | Evidence |
| --- | --- | --- | --- |
| 1 | realizes through five `is-a` levels | **Met** | `spw:feeds realizes cyc:CatalogueIngestion via [shimano_xml.py#parse_feed, spk:ShimanoXmlImporter]`. No GM320 on the four `is-a`-only importers. `drift --all` shows `spw:feeds ... ⊑ declared {cyc:CatalogueIngestion}`. |
| 2 | realizes up `part-of` chains | **Met** | `spw:scanning` derives `spk:BinRouter`, `spk:WaveBuilder`, `spk:PickPlanner`, `spk:FulfilmentEngine` and `cyc:OrderFulfilment` from one marker on `spk:ScanVerifier`, five levels down. Its manifest declares `cyc:OrderFulfilment` and is consistent. |
| 3 | Subsumption is directional | **Met for `is-a`, failed for `part-of`** | `spw:listing` declares `cyc:Product` and covers leaves four to seven levels down. Declaring a child and implementing its `is-a` parent is a violation plus a gap, which is correct. Declaring a leaf part and implementing its whole is reported as consistent ([F-DEEP-1](#f-deep-1-a-declared-part-covers-its-whole-so-a-leaf-declaration-admits-the-entire-process)). |
| 4 | range-lcs | **Met, one silent case** | Depths 7 and 4 lift to `cyc:DrivetrainComponent`. A second-parent-only LCS lifts to `cyc:PoweredDevice`. With two incomparable subsumers, nothing is lifted and nothing says why ([F-DEEP-9](#f-deep-9-range-lcs-is-silent-when-there-is-no-unique-subsumer-and-drops-a-curated-views-edges)). |
| 5 | `check --explain` readable | **Partly** | The sets are correct and include `is-a` and `part-of` descendants. They print as one flat, alphabetical line of up to 695 characters, with no structure and no reason per entry ([F-DEEP-11](#f-deep-11-check---explain-prints-a-flat-line-and-the-docs-omit-core-tier-inheritance)). |
| 6 | Violations scale with the omission | **Failed** | One omission under two `inherit` levels gives 10 lines of 432 to 669 characters. One marker on a deep part gives one violation per whole above it ([F-DEEP-6](#f-deep-6-the-number-of-violations-grows-with-depth-not-with-the-mistake)). |
| 7 | `realizes: inherit` across three levels | **Met** | The root's declared set resolves to `{cyc:CatalogueIngestion, cyc:OrderFulfilment, cyc:Picking, cyc:Product, cyc:ProductListing, spk:FulfilmentEngine}`. A gap three levels down is reported once, at `services/catalogue/ingest/feeds/.gloss.yaml:1`. |
| 8 | Criticality | **Met, provenance one hop only** | `cyc:HydraulicDiscBrake critical from cyc:DiscBrake`. `spk:ScanVerifier high from spk:BinRouter`. With two parents at `medium` and `high`, the child is `high`. `criticality-from` names only the nearest hop, not the declared source ([F-DEEP-7](#f-deep-7-provenance-shows-one-hop-so-a-deep-derivation-cannot-be-explained)). |
| 9 | Viewer projection | **Partly** | Deepest-boundary placement works for leaves. The top-level `cyc:OrderFulfilment` lands in the leaf box `spw:scanning` ([F-DEEP-10](#f-deep-10-the-viewer-places-a-top-level-whole-in-a-leaf-component)). The business view folds `spk:Importer`, which has no code, and omits its code-bearing descendants ([F-DEEP-7](#f-deep-7-provenance-shows-one-hop-so-a-deep-derivation-cannot-be-explained)). |
| 10 | Cycles detected | **Failed** | No diagnostic for any of five cycles. Nothing hangs. The `is-a` cycle hides two violations and a gap ([F-DEEP-3](#f-deep-3-cycles-are-never-detected-and-an-is-a-cycle-silently-widens-every-declaration)). |
| 11 | Kind via `is-a` | **Failed** | `represents cyc:HydraulicDiscBrake` does not lift to `holds`, which gives a false gap ([F-DEEP-2](#f-deep-2-kind-is-not-inherited-through-is-a-so-represents-on-a-subtype-gives-a-false-gap)). |

**What worked well.** List-valued `is-a` and `part-of` parse and build. `realizes` inherits through five `is-a` levels and up five `part-of` levels in both tiers, with no extra `realizes:` lines. A declared root covers leaves seven levels down, and the reverse is correctly a violation for `is-a`. range-lcs is right in every case with a unique answer, including unequal depths and multiple inheritance. `realizes: inherit` composes across three manifest levels and reports gaps once, at the right child. Criticality flows through `is-a` and `part-of` in both tiers and takes the highest parent. Cycles never hang `check`, `build`, `drift` or `view`.

Already reported elsewhere and not repeated here: F-ADOPT-6 (an inheriting parent reports a child's undeclared `realizes`). [F-DEEP-6](#f-deep-6-the-number-of-violations-grows-with-depth-not-with-the-mistake) measures how depth multiplies it.

---

## F-DEEP-1: a declared part covers its whole, so a leaf declaration admits the entire process

**Problem.** GRAPH.md says a declared concept covers a derived one "when they are equal, when the declared one subsumes it (`is-a*`), or when the derived one realizes it". FILE-FORMATS.md adds that "a part realizes its whole", so code implementing a part satisfies a manifest that declares the whole. v0.1.0 also applies the reverse. A manifest that declares a **part** covers code that realizes the **whole**, and the declared part counts as implemented when only the whole is. A component that declares the scan-confirmation step can therefore implement all of order fulfilment, with no violation and no gap. The same shape on `is-a` is correctly a violation plus a gap, so the two hierarchies disagree.

**Repro.** In a copy of `catalogue/`, `services/fulfilment/picking/scanning/.gloss.yaml` declares `realizes: [cyc:ScanConfirm]` (the leaf of `OrderFulfilment > Picking > PickWave > BinPick > ScanConfirm`). `verifier.py` is changed to `@gloss implements cyc:OrderFulfilment`. Then:

```
$ gloss build && gloss drift --all --fail-on none | grep spw:scanning
  spw:scanning realizes {cyc:OrderFulfilment} ⊑ declared {cyc:ScanConfirm}
```

There is no violation, and no gap for `cyc:ScanConfirm`, which nothing implements. The `is-a` control in the same copy declares `cyc:Cassette` and implements its parent `cyc:DrivetrainComponent`:

```
  spw:scanning realizes cyc:DrivetrainComponent but declares realizes {cyc:Cassette}; rollup: realizes {cyc:DrivetrainComponent} ⊄ declared  [services/fulfilment/picking/scanning/verifier.py:11]
  spw:scanning declares realizes cyc:Cassette but nothing under it implements it: intended capability not implemented, or the declaration is wrong  [services/fulfilment/picking/scanning/.gloss.yaml:1]
```

The same leak shows in `drift --all` on the committed workspace: `spw:picking` declares `cyc:Picking`, and its derived `cyc:OrderFulfilment` (the whole above it) is consistent. `run.sh` prints both cases under "F-DEEP-1".

**Proposed change.** Make `part-of` coverage one-directional, as `is-a` already is. A declared whole covers a derived part (a part realizes its whole). A declared part never covers a derived whole. A gap on a declared part is closed only by code that realizes that part or one of its parts. Say so in GRAPH.md's coverage paragraph.

**Done when.** The repro prints a violation `spw:scanning realizes cyc:OrderFulfilment but declares realizes {cyc:ScanConfirm}` and a gap for `cyc:ScanConfirm`. The committed `catalogue/` keeps zero violations, because `spw:scanning` declares the whole.

## F-DEEP-2: kind is not inherited through is-a, so represents on a subtype gives a false gap

**Problem.** FILE-FORMATS.md says `kind` is "required unless `is-a` is given", which implies a subtype takes its ancestor's kind. In v0.1.0 the subtype has no kind at all. The graph node carries none, `gloss impact` prints an empty kind, and kind-dependent rules skip it. The rule that matters is "`represents` on an `entity` lifts to `holds`". A table that `represents cyc:HydraulicDiscBrake` (an entity through five `is-a` levels) derives no `holds`. A manifest declaring it gets a **false gap**, which fails `drift` by default. In a deep taxonomy almost every concept is a subtype, so every data boundary that holds a specific kind of product hits this. `provisions`, `configures` and `deploys` on a `resource` or `system-type` subtype probably have the same defect. That is not tested here.

**Repro.** `catalogue/services/catalogue/db/.gloss.yaml` declares `holds: [cyc:Product, cyc:HydraulicDiscBrake]`. `0001_products.sql` marks one table `represents cyc:Product` (declared `kind: entity`) and one table `represents cyc:HydraulicDiscBrake` (`is-a: DiscBrake`, no `kind`).

```
$ cd catalogue && gloss drift
○ Gaps (declared, not implemented)
  spw:catalogue-db declares holds cyc:HydraulicDiscBrake but nothing under it represents it: intended capability not implemented, or the declaration is wrong  [services/catalogue/db/.gloss.yaml:1]

$ grep '"curie":"cyc:HydraulicDiscBrake"' .glossmark/graph.jsonl     # no "kind" key
{"type":"node","node":"concept","id":"https://onto.spokewise.example/core/HydraulicDiscBrake","curie":"cyc:HydraulicDiscBrake","ns":"cyc","tier":"core","doc":"A disc brake actuated by fluid.","criticality":"critical","criticality-from":"cyc:DiscBrake","file":"ontology/cyc.gloss.yaml","line":24}

$ gloss impact services/catalogue/ingest/feeds/shimano_xml.py | grep '(, '
  cyc:Cassette (, core)
  cyc:ElectronicFrontDerailleur (, core)
  cyc:ElectronicRearDerailleur (, core)
  spk:ShimanoXmlImporter (, implementation, high)
```

Adding `kind: entity` to `cyc:HydraulicDiscBrake` in a copy turns the gap into `spw:catalogue-db holds {cyc:HydraulicDiscBrake, cyc:Product} ⊑ declared {cyc:HydraulicDiscBrake, cyc:Product}`.

**Proposed change.** Resolve an effective `kind` at build time from the nearest `is-a` ancestor that declares one. Write it to the graph node with `kind-from`, as criticality already does with `criticality-from`. Use it in every kind-dependent rule: the holds lift, the resource and system-type lifts, and impact output. When two parents give different kinds, report a lint error. Document the inheritance next to the `kind` row in FILE-FORMATS.md.

**Done when.** `gloss drift` in `catalogue/` reports no gap for `spw:catalogue-db`. The `cyc:HydraulicDiscBrake` node carries `"kind":"entity"`. `gloss impact` prints `cyc:Cassette (entity, core)`.

## F-DEEP-3: cycles are never detected, and an is-a cycle silently widens every declaration

**Problem.** `gloss check`, `build`, `drift` and `view` accept every cycle without a diagnostic. `cycles/` has five: an `is-a` cycle (`Product is-a Lighting`, which closes `Product > Accessory > Lighting > Product`), an `is-a` self-loop (`Brake is-a Brake`), a core `part-of` cycle, an implementation `part-of` cycle, and a boundary `part-of` cycle. Nothing hangs, but the effects are wrong in ways a reader cannot trace back:

- The `is-a` cycle makes every concept on it subsume every other concept and all their descendants. `spw:listing` declares `cyc:Lighting`, and code realizing `cyc:Cassette` (a `Component`) passes. The violation for it and the gap for `cyc:Lighting` both vanish.
- GM320 requires an implementation concept to realize something or be `is-a`/`part-of` one that does. `spk:WaveBuilder part-of spk:BinRouter part-of spk:WaveBuilder` realizes nothing, and GM320 stays silent. As a control, a lone concept with no `realizes` does get `[GM320]` in the same workspace.
- The boundary cycle (`spw:listing part-of spw:picking part-of spw:listing`) makes each boundary roll up the other's code. Both get violations blamed on the other's files. Also, `spw:picking` is recorded with the wrong file, level and directory ([F-DEEP-4](#f-deep-4-a-parent-boundary-in-a-sibling-directory-is-recorded-with-the-childs-manifest)).

A one-line merge mistake in an ontology file can create an `is-a` cycle. FILE-FORMATS.md classes any change to `is-a` as MAJOR, so this edge deserves a hard error.

**Repro.**

```
$ cd cycles && gloss check
services/listing/cassettes.py:12: warning: implements spk:CassetteListing is outside the allowed set derived from services/listing/.gloss.yaml (HARD gate); ... [GM503]
gloss check: 0 errors, 1 warning

$ gloss drift --fail-on none | grep '^  spw:listing'
  spw:listing realizes spk:BinRouter but declares realizes {cyc:Lighting}; ...  [services/picking/waves.py:4]
  spw:listing realizes spk:WaveBuilder but declares realizes {cyc:Lighting}; ...  [services/picking/waves.py:4]
```

Control, the same workspace without `is-a: Lighting` on `cyc:Product`:

```
  spw:listing realizes cyc:Cassette but declares realizes {cyc:Lighting}; rollup: realizes {cyc:Cassette, spk:BinRouter,
  spw:listing realizes spk:BinRouter but declares realizes {cyc:Lighting}; ...
  spw:listing realizes spk:CassetteListing but declares realizes {cyc:Lighting}; ...
  spw:listing realizes spk:WaveBuilder but declares realizes {cyc:Lighting}; ...
  spw:listing declares realizes cyc:Lighting but nothing under it implements it: ...
```

**Proposed change.** Add three `gloss check` errors, each naming the cycle's members in order with file and line for every edge:

- An `is-a` cycle, self-loops included.
- A `part-of` or `has-part` cycle in either tier.
- A boundary `part-of` cycle across manifests.

Make GM320 follow `is-a` and `part-of` to a concept that actually realizes something, rather than accepting any outgoing edge. `gloss diff` should treat a new cycle as HARD.

**Done when.** `gloss check` in `cycles/` exits non-zero with one error per cycle, five in all, plus GM320 on `spk:WaveBuilder` and `spk:BinRouter`.

## F-DEEP-4: a parent boundary in a sibling directory is recorded with the child's manifest

**Problem.** A boundary may name any boundary in `part-of`, not just the one in its parent directory. That is how a logical parent (a domain, a platform) is modelled when it lives beside its children. When the child's manifest is processed first, its `part-of` reference creates the parent node, and the parent's own manifest then fails to replace it. The parent node ends up with the child's `file`, no `dir`, and `kind: system` whatever its manifest says. Its `label`, `owner` and `realizes` are merged in correctly, so the effect is easy to miss. The visible damage:

- Every finding on the parent points at the child's manifest.
- The viewer draws the parent as a `system`.
- The graph has no directory for the parent.

The order looks like depth first, then name. With `apps/checkout/` and `platform/` the bug does not trigger. With `checkout/` and `platform/` it does. In a scratch test, `a/` part-of `b/` triggers it and `zz/` part-of `b/` does not.

**Repro.** `sibling-parent/platform/.gloss.yaml` declares `boundary: spw:platform`, `level: domain`, `realizes: [cyc:Payment, cyc:Refund]`. `sibling-parent/checkout/.gloss.yaml` declares `part-of: spw:platform`.

```
$ cd sibling-parent && grep '"node":"boundary"' .glossmark/graph.jsonl
{..."curie":"spw:checkout","ns":"spw","kind":"container","owner":"checkout-team","dir":"checkout","file":"checkout/.gloss.yaml","line":1}
{..."curie":"spw:platform","ns":"spw","kind":"system","label":"Commerce platform","owner":"platform-team","file":"checkout/.gloss.yaml","line":1}

$ gloss drift | grep Refund
  spw:platform declares realizes cyc:Refund but nothing under it implements it: ...  [checkout/.gloss.yaml:1]
```

The two violations for `cyc:Checkout` and `spk:CheckoutFlow` at `spw:platform` are correct: the checkout code is part of the platform, and the platform does not declare checkout.

**Proposed change.** Load every manifest before resolving `part-of` references. A reference to a boundary that has a manifest must never create or overwrite that boundary's node. A reference to a boundary that has no manifest should create a stub with no `kind`. It should not default to `system`.

**Done when.** The `spw:platform` node has `"kind":"domain","dir":"platform","file":"platform/.gloss.yaml"`, and the Refund gap points at `[platform/.gloss.yaml:1]`.

## F-DEEP-5: the derived allowed set leaves out implementation concepts that realize what a boundary declares

**Problem.** The derived allowed set is the declared concepts, "their `part-of` and `is-a` descendants, the core concepts they realize", and nested boundaries (FILE-FORMATS.md). It never includes the implementation concepts that **realize** a declared core concept. So a boundary that declares `cyc:CatalogueIngestion` warns GM503, HARD in the gate, on every importer that realizes it. `drift` reports the same boundary as consistent, because its coverage rule accepts "the derived one realizes it". `check` and `drift` disagree about the same link.

Without `default-namespace`, every implementation link in `catalogue/` is GM503: 10 warnings, 0 violations. With `default-namespace: spk`, every `spk:` concept is allowed, including unrelated ones. Neither gives "the implementation of what I declare".

Declaring the implementation root instead only half works. `realizes: [spk:Importer]` admits its five `is-a` levels, but not `spk:CsvRowParser`, which is `part-of` an `is-a` descendant. Descendants are followed along one relation at a time, not along mixed chains. `drift` covers `spk:CsvRowParser` either way.

**Repro.**

```
$ cd catalogue && gloss check 2>&1 | tail -2
services/fulfilment/picking/scanning/verifier.py:11: warning: implements spk:ScanVerifier is outside the allowed set derived from services/fulfilment/picking/scanning/.gloss.yaml (HARD gate); ... [GM503]
gloss check: 0 errors, 10 warnings

$ gloss check --explain | grep '^spw:scanning'
spw:scanning (services/fulfilment/picking/scanning/.gloss.yaml): allowed = cyc:BinPick, cyc:OrderFulfilment, cyc:PickWave, cyc:Picking, cyc:ScanConfirm  [derived: ...]

$ gloss drift --all --fail-on none | grep 'spw:scanning'
  spw:scanning realizes {cyc:OrderFulfilment, spk:BinRouter, spk:FulfilmentEngine, spk:PickPlanner, spk:ScanVerifier, spk:WaveBuilder} ⊑ declared {cyc:OrderFulfilment}
```

Mixed chain, in a copy where `feeds` declares `realizes: [spk:Importer]`:

```
spw:feeds (...): allowed = ..., spk:CsvFeedImporter, spk:FeedImporter, spk:Importer, spk:ShimanoXmlImporter, spk:SupplierImporter, spk:XmlFeedImporter  [derived: ...]
services/catalogue/ingest/feeds/csv_feed.py:23: warning: implements spk:CsvRowParser is outside the allowed set derived from services/catalogue/ingest/feeds/.gloss.yaml (HARD gate); ... [GM503]
  spw:feeds realizes {cyc:CatalogueIngestion, spk:CsvFeedImporter, spk:CsvRowParser, spk:ShimanoXmlImporter} ⊑ declared {spk:Importer}
```

**Proposed change.** Derive the allowed set from the same coverage relation `drift` uses. Add every concept whose `realizes` closure, following `is-a` and `part-of` in any order, reaches a declared concept. Close descendants over mixed `is-a`/`part-of` chains. Update FILE-FORMATS.md to list these sources, alongside the `holds`/`presents`/`hosts` fix that F-ADOPT-4 already asks for.

**Done when.** `gloss check` in `catalogue/` prints 0 warnings, and the mixed-chain copy has no GM503 on `spk:CsvRowParser`.

## F-DEEP-6: the number of violations grows with depth, not with the mistake

**Problem.** This extends F-ADOPT-6. That finding covers one inheriting parent and one undeclared child. Depth multiplies the output on two axes:

1. **Inherit levels.** One omission is reported at every ancestor whose resolved declared set is non-empty. It is never reported at the boundary that omitted the declaration. Leaving the realizes line out of `feeds` and making `ingest` inherit-only gives nothing at `spw:ingest`, whose resolved set is empty. It gives 5 violations at `spw:catalogue` and 5 at `spw:spokewise`. That is 10 lines of 432 to 669 characters, and no line names either manifest that caused it.
2. **Partonomy depth.** A violation is listed once per derived concept. A marker on a part five levels down derives the part and every whole above it. One marker on `spk:ScanVerifier` gives 5 violations at `spw:picking`, one each for `ScanVerifier`, `BinRouter`, `WaveBuilder`, `PickPlanner` and `FulfilmentEngine`, all citing the same line.

Each line repeats the full declared set and the full derived set. At the root that is 22 derived concepts per line.

**Repro.** In a copy of `catalogue/`, `services/catalogue/ingest/.gloss.yaml` is changed to `realizes: inherit` and the `realizes:` line in `services/catalogue/ingest/feeds/.gloss.yaml` is removed:

```
$ gloss drift --fail-on none | grep '^  spw:.* but declares ' | awk '{print length($0)}'
440 437 434 432 443 666 663 660 658 669

  spw:spokewise realizes spk:ShimanoXmlImporter but declares realizes {cyc:OrderFulfilment, cyc:Picking, cyc:Product, cyc:ProductListing, spk:FulfilmentEngine}; rollup: realizes {cyc:BinPick, cyc:CatalogueIngestion, cyc:ElectronicRearDerailleur, cyc:FrontLight, cyc:HydraulicDiscBrake, cyc:OrderFulfilment, cyc:PickWave, cyc:Picking, cyc:ProductListing, spk:BinPickHandler, spk:BinRouter, spk:BrakeListing, spk:CsvFeedImporter, spk:CsvRowParser, spk:DerailleurListing, spk:FulfilmentEngine, spk:IngestScheduler, spk:LightListing, spk:PickPlanner, spk:ScanVerifier, spk:ShimanoXmlImporter, spk:WaveBuilder} ⊄ declared  [services/catalogue/ingest/feeds/shimano_xml.py:22]
```

Fan-out, in a copy where `services/fulfilment/picking/.gloss.yaml` says `realizes: [cyc:Picking]`:

```
  spw:picking realizes spk:BinRouter but declares realizes {cyc:Picking}; rollup: realizes {cyc:BinPick, cyc:O...
  spw:picking realizes spk:FulfilmentEngine but declares realizes {cyc:Picking}; ...
  spw:picking realizes spk:PickPlanner but declares realizes {cyc:Picking}; ...
  spw:picking realizes spk:ScanVerifier but declares realizes {cyc:Picking}; ...
  spw:picking realizes spk:WaveBuilder but declares realizes {cyc:Picking}; ...
```

**Proposed change.** Group violations by cause:

- **One finding per artifact link.** Report the link that introduces the excess once, with the concepts it lifts to listed under it, for example `spk:ScanVerifier (and the 4 wholes it is part of)`.
- **One finding at the boundary that omitted.** With `inherit`, report at the nearest descendant boundary whose code derives the concept and which declares nothing for that relation. Name that boundary's manifest, as F-ADOPT-6 proposes, and do not repeat the finding at each ancestor.
- **Sets printed once per boundary.** Print the declared and derived sets once per boundary in a header, collapsed by subsumption (`cyc:Product (+17 below)`), not on every line.

**Done when.** The first repro prints one finding that names `services/catalogue/ingest/feeds/.gloss.yaml`. The second prints one finding for `services/fulfilment/picking/scanning/verifier.py:11`.

## F-DEEP-7: provenance shows one hop, so a deep derivation cannot be explained

**Problem.** Every derived fact keeps only the first and last step. A reader of a deep hierarchy cannot answer "why does this boundary realize that?" or "where does this criticality come from?" without walking the ontology by hand.

- **`via` on derived `realizes`** lists the artifact and the concept it links, never the `is-a` or `part-of` path in between. `spw:feeds realizes cyc:CatalogueIngestion via [shimano_xml.py#parse_feed, spk:ShimanoXmlImporter]` hides the four `is-a` steps up to `spk:Importer`, which is what says `realizes:`.
- **`criticality-from`** names the nearest neighbour, not the declared source. `cyc:HydraulicDiscBrake critical from cyc:DiscBrake`, `cyc:DiscBrake critical from cyc:Brake`, `cyc:Brake critical from cyc:BrakingComponent`. That is three lookups to reach `declared`. `spk:ShimanoXmlImporter high from spk:XmlFeedImporter` needs four.
- **The business view's `folded` list** has only direct realizers. `cyc:CatalogueIngestion folds ['spk:Importer', 'spk:IngestScheduler']`. `spk:Importer` has no code. The three importer concepts that do have code (`spk:ShimanoXmlImporter`, `spk:CsvFeedImporter`, and `spk:CsvRowParser` as a part of the latter) reach the core concept only through `is-a` or `part-of`. They are folded nowhere and vanish from the view. By contrast `cyc:OrderFulfilment` lists all five `part-of` levels.
- **Lifting asymmetry.** A `part-of` chain lifts every intermediate whole into the boundary's derived set. An `is-a` chain lifts only the core concept, so `spk:XmlFeedImporter` through `spk:Importer` never appear. The result is right, but the two relations look different to a reader for no stated reason.

**Repro.** `cd catalogue`, then run the "Derived realizes" and "Criticality" sections of `run.sh`, or:

```
$ grep '"p":"realizes"' .glossmark/graph.jsonl | grep 'spw/feeds' | grep -o '"via":[^]]*]'
"via":["services/catalogue/ingest/feeds/csv_feed.py#parse_row","spk:CsvRowParser"]
"via":["services/catalogue/ingest/feeds/csv_feed.py#import_csv","spk:CsvFeedImporter"]
"via":["services/catalogue/ingest/feeds/shimano_xml.py#parse_feed","spk:ShimanoXmlImporter"]
...
```

**Proposed change.**

- **Full `via` path.** Record the whole path, for example `[artifact, spk:ShimanoXmlImporter, is-a spk:XmlFeedImporter, ..., is-a spk:Importer, realizes cyc:CatalogueIngestion]`.
- **Declared source of criticality.** Add `criticality-source` (the concept that declared the level) next to `criticality-from`.
- **Transitive folding.** In `collapse: via realizes`, fold every concept whose realizes closure reaches the core concept, so `is-a` descendants are listed.
- **`gloss explain <boundary> <concept>`.** Print the chain on demand.

**Done when.** The `spw:feeds` → `cyc:CatalogueIngestion` edge from `shimano_xml.py` names `spk:Importer` in its `via`. The `cyc:HydraulicDiscBrake` node names `cyc:BrakingComponent` as its declared source. The business view's fold of `cyc:CatalogueIngestion` contains `spk:ShimanoXmlImporter`.

## F-DEEP-8: abstract taxonomy nodes are orphans unless code links a descendant directly

**Problem.** Whether an abstract supertype counts as an orphan depends on how its descendants are reached. If code links a descendant directly (`produces`, `represents`), every `is-a` ancestor is exempt. If the descendant is reached only through an implementation concept that realizes it, the ancestors are orphans.

In the committed `catalogue/`, `cyc:Accessory` and `cyc:Lighting` are orphans. Their descendant `cyc:FrontLight` is realized by `spk:LightListing`, which has code. `cyc:PoweredDevice`, the other parent of `cyc:FrontLight`, is not an orphan, because `cyc:ElectronicRearDerailleur` (also a `PoweredDevice`) is produced directly.

Removing the `produces` markers adds 8 orphans. Two are leaves that were only produced, which is correct. Six are supertypes that the same code still reaches by realization: `cyc:DrivetrainComponent`, `cyc:ShiftingComponent`, `cyc:Derailleur`, `cyc:RearDerailleur`, `cyc:FrontDerailleur` and `cyc:PoweredDevice`. In a deep taxonomy this produces a long orphan list of classification nodes that nobody is expected to link, and the list changes with unrelated markers.

**Repro.**

```
$ cd catalogue && gloss drift --fail-on none | grep orphan
  cyc:Accessory: orphan concept, no artifact links to it  [ontology/cyc.gloss.yaml:25]
  cyc:Lighting: orphan concept, no artifact links to it  [ontology/cyc.gloss.yaml:26]
  cyc:ScanConfirm: orphan concept, no artifact links to it  [ontology/cyc.gloss.yaml:44]
```

`run.sh` section "F-DEEP-8" removes the `produces` markers and lists 11 orphans.

**Proposed change.** A concept is not an orphan when any `is-a` descendant has an artifact by any route, realization included. Optionally, report supertypes with no direct artifact under a separate, non-failing `abstract` label, so `orphan` keeps meaning "nothing below it is built".

**Done when.** `cyc:Accessory` and `cyc:Lighting` are not orphans in `catalogue/`. Removing the `produces` markers adds only `cyc:Cassette` and `cyc:ElectronicFrontDerailleur`.

## F-DEEP-9: range-lcs is silent when there is no unique subsumer, and drops a curated view's edges

**Problem.** Two separate rough edges in `lift: range-lcs`:

1. **No unique answer, no notice.** `{ElectronicRearDerailleur, ElectronicFrontDerailleur}` has two incomparable minimal common subsumers, `cyc:Derailleur` (depth 5) and `cyc:PoweredDevice` (depth 2). The two concepts share both parents' lines. v0.1.0 lifts nothing and prints the raw set, with no sign that a lift was attempted. Declining to choose is defensible. Silence makes it look as if range-lcs is off.
2. **Curated views lose the named concepts' edges.** In a curated view, which keeps only "edges with at least one named end", `lift: range-lcs` first replaces the boundary's `produces {Cassette, ElectronicFrontDerailleur, ElectronicRearDerailleur}` with `produces cyc:DrivetrainComponent`. That concept is not named, so the edge is dropped. A view written to show what produces the drivetrain parts shows no `produces` edge at all.

Also, when the lifted set fails, the message names the offending concept but shows the lifted summary: `produces cyc:FrontLight ... rollup: produces {cyc:PoweredDevice} ⊄ declared`. That is correct but reads oddly, because `PoweredDevice` is never produced. A clause that names the summarised members would help.

**Repro.** `run.sh` section "F-DEEP-9", and the `drivetrain` view in `catalogue/ontology/views.yaml`:

```
-- produces {cyc:ElectronicRearDerailleur, cyc:Cassette}
  spw:feeds produces {cyc:DrivetrainComponent} ⊑ declared {cyc:Component}
-- produces {cyc:RearDerailleur, cyc:FrontDerailleur}
  spw:feeds produces {cyc:Derailleur} ⊑ declared {cyc:Component}
-- produces {cyc:ElectronicRearDerailleur, cyc:ElectronicFrontDerailleur}
  spw:feeds produces {cyc:ElectronicFrontDerailleur, cyc:ElectronicRearDerailleur} ⊑ declared {cyc:Component}
-- produces {cyc:ElectronicRearDerailleur, cyc:FrontLight}
  spw:feeds produces cyc:FrontLight but declares produces {cyc:Component}; rollup: produces {cyc:PoweredDevice} ⊄ declared  [...shimano_xml.py:23]

drivetrain (curated, lift: range-lcs) edges: [('spw:listing', 'realizes', 'cyc:ElectronicRearDerailleur')]
```

The same view without `lift:` has three `spw:feeds produces` edges.

**Proposed change.** When no unique LCS exists, print `(no unique subsumer: cyc:Derailleur, cyc:PoweredDevice)` after the set in drift and as a property in the projection. Document the rule in GRAPH.md. In curated views, apply the lift only to edges whose ends are not named, or keep the named members as `lifted-from` on the lifted edge. In a violation, write `rollup: produces {cyc:PoweredDevice} (from cyc:ElectronicRearDerailleur, cyc:FrontLight)`.

**Done when.** The ambiguous case prints the "no unique subsumer" note. The `drivetrain` view has `spw:feeds produces` edges to its three named concepts.

## F-DEEP-10: the viewer places a top-level whole in a leaf component

**Problem.** The placement rule ranks "own code links to it directly" above "manifest only declares it" above "reaches it by lifting", then takes the deepest. To satisfy drift, a leaf component whose code implements a deep part declares the top-level whole, as `spw:scanning` declares `cyc:OrderFulfilment`. The container's code (`engine.py` implements `spk:FulfilmentEngine`, which realizes `cyc:OrderFulfilment` directly) appears to count only as lifting, so the declaration wins. The result is that `cyc:OrderFulfilment` is drawn inside `spw:scanning`, three levels below the container that runs it. Its parts `spk:PickPlanner` and `spk:WaveBuilder` sit in the same leaf box, while their whole `spk:FulfilmentEngine` sits in `spw:fulfilment`.

**Repro.**

```
$ cd catalogue && gloss view --json -o /tmp/v.json   # then read view "components"
components: cyc:OrderFulfilment -> spw:scanning
components: spk:FulfilmentEngine -> spw:fulfilment
components: spk:PickPlanner -> spw:scanning
```

**Proposed change.** Count code that implements a concept whose own `realizes` names the target directly as a direct link, so `engine.py` beats a declaration. When the candidates of a `part-of` whole sit in nested boundaries, place the whole in the nearest boundary that encloses them all. Never place a whole deeper than any of its parts' boundaries.

**Done when.** `cyc:OrderFulfilment` is placed in `spw:fulfilment` in the `components` view.

## F-DEEP-11: check --explain prints a flat line, and the docs omit core-tier inheritance

**Problem.** Two smaller points.

1. **Explain output.** `check --explain` prints each manifest's effective set as one alphabetical line: 30 entries and 695 characters at `spw:spokewise`, 509 at `spw:catalogue-db`, which declares two concepts. Eighteen of the root's entries are `cyc:Product` and its 17 descendants, but the line does not show that. The bracketed suffix lists every possible source (`default-namespace, declared concepts, their descendants, realized cores, nested boundaries`) even when a manifest has no default namespace and no nested boundaries, so it never says where a given entry came from.
2. **Core-tier inheritance is undocumented.** GOVERNANCE.md says "an implementation concept takes the highest level of what it realizes ... then of the concept it is part-of; then of its is-a ancestors". v0.1.0 applies the same inheritance to **core** concepts: `cyc:HydraulicDiscBrake critical from cyc:DiscBrake`, `cyc:ScanConfirm high from cyc:BinPick`. That is the useful behaviour, but the docs do not promise it.

**Repro.**

```
$ cd catalogue && gloss check --explain 2>/dev/null | grep 'allowed =' | awk '{print length($0), $1}'
695 spw:spokewise
547 spw:catalogue
...
```

**Proposed change.** Print the set as a tree grouped by source, and collapse a declared concept with all its descendants into one entry, for example:

```
spw:catalogue-db (services/catalogue/db/.gloss.yaml)
  declared  cyc:Product (+17 is-a descendants), cyc:HydraulicDiscBrake
```

Add `--format json` with one record per entry and its reason. In GOVERNANCE.md, say that core concepts inherit criticality through `is-a` and `part-of` too.

**Done when.** `check --explain` for `spw:catalogue-db` fits in three lines and names `cyc:Product` as the source of its descendants. GOVERNANCE.md describes core-tier inheritance.
