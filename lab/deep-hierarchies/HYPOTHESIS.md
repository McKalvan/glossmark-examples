# Hypothesis: deep hierarchies

## The question

Real domains have deep taxonomies and deep partonomies. A parts catalogue classifies an electronic rear derailleur seven levels below "product", and a warehouse process breaks "order fulfilment" into picking, pick waves, bin picks and scan confirmation. Code is usually written against the leaves, while manifests and reviewers think in terms of the upper levels. GlossMark promises that this works without repetition: "a concept inherits `realizes` through `is-a` and a part realizes its whole" (FILE-FORMATS.md), a declared concept covers a derived one "when the declared one subsumes it (`is-a*`)" (GRAPH.md), `range-lcs` summarises a set by its least common subsumer, `realizes: inherit` saves restating children's lists, and criticality flows through `is-a` and `part-of` (GOVERNANCE.md).

Does all of that hold when the hierarchies are five to seven levels deep, include multiple inheritance, and are nested inside four levels of boundary manifests? And are the diagnostics still readable at that depth?

This matters for an adopter because the derived sets are what a reviewer reads. If depth makes them wrong, the gate is wrong. If depth makes them unreadable, nobody checks them.

## The model

`catalogue/` is Spokewise, an online bicycle parts shop, written in Python with one SQL migration.

- **Core tier `cyc:`.** A product taxonomy seven levels deep (`Product > Component > DrivetrainComponent > ShiftingComponent > Derailleur > RearDerailleur > ElectronicRearDerailleur`), with two multiple-inheritance leaves (`ElectronicRearDerailleur` and `ElectronicFrontDerailleur` are also `PoweredDevice`). `FrontLight` is both `Lighting` and `PoweredDevice`. `BrakingComponent` is `critical`. An order-fulfilment partonomy five levels deep (`OrderFulfilment > Picking > PickWave > BinPick > ScanConfirm`). `produces` lifts with `range-lcs`.
- **Implementation tier `spk:`.** An importer taxonomy five levels deep (`Importer > SupplierImporter > FeedImporter > XmlFeedImporter > ShimanoXmlImporter`) where only the root says `realizes:`. A fulfilment-engine partonomy five levels deep (`FulfilmentEngine > PickPlanner > WaveBuilder > BinRouter > ScanVerifier`) where only the root says `realizes:`. A mixed chain: `CsvRowParser part-of CsvFeedImporter is-a FeedImporter`.
- **Boundaries.** Nine manifests, up to four levels: `spokewise` (system, `realizes: inherit`) > `catalogue` (container, `inherit`) > `ingest` (component, `[inherit, cyc:CatalogueIngestion]`) > `feeds` (component). Also `listing`, `catalogue-db`, and `fulfilment` > `picking` > `scanning`. No manifest sets `default-namespace`, so the derived allowed sets are visible unmasked.
- **Views.** The two presets, a `components` view at component zoom with `expand: { part-of: 5 }`, and a curated `drivetrain` view with `lift: range-lcs`.

Two more workspaces isolate specific defects: `cycles/` holds an `is-a` cycle, an `is-a` self-loop, a `part-of` cycle in each tier and a boundary `part-of` cycle. `sibling-parent/` has a boundary whose `part-of` names a boundary in a sibling directory.

`run.sh` reproduces every output quoted in FINDINGS.md, applying mutations to temporary copies.

## What "GlossMark handles this well" looks like

Each item names the command and the output that would confirm it.

1. **realizes through five `is-a` levels.** Code that implements `spk:ShimanoXmlImporter` makes `spw:feeds` realize `cyc:CatalogueIngestion`. `gloss check` raises no GM320 on the four `is-a`-only importers. `drift --all` shows `spw:feeds` consistent.
2. **realizes up `part-of` chains.** Code that implements `spk:ScanVerifier` makes `spw:scanning` realize `cyc:OrderFulfilment`. A manifest that declares the top of the chain is consistent.
3. **Subsumption in drift is directional.** A manifest declaring `cyc:Product` covers code realizing a leaf six levels down. A manifest declaring a leaf does **not** cover code realizing an ancestor. That holds for `is-a` and for `part-of`: a part is not its whole.
4. **range-lcs picks the right subsumer.** `{ElectronicRearDerailleur, Cassette}` (depths 7 and 4) lifts to `DrivetrainComponent`. `{ElectronicRearDerailleur, FrontLight}` lifts to `PoweredDevice` through the second parent. When two incomparable subsumers exist (`Derailleur` and `PoweredDevice`), the tool says so, or picks one by a documented rule.
5. **`check --explain` stays readable.** The effective set of a deeply nested boundary is shown in a form a reviewer can scan, and the derivation of each entry is recoverable.
6. **Violation messages scale.** A single omission produces a number of findings proportional to the omission, not to the depth of the tree or the size of the derived set.
7. **`realizes: inherit` across three levels.** The root's declared set is the union of what the leaves declare. A gap is reported once, by the child that declared it.
8. **Criticality.** `cyc:HydraulicDiscBrake` (three `is-a` levels below `critical`) is critical, as are the code and boundaries that realize it. `spk:ScanVerifier` (four `part-of` levels below a `high` concept) is high. A concept with two parents takes the higher level. `criticality-from` lets a reviewer find the declared source.
9. **Viewer projection.** In `gloss view --json`, each concept lands in the deepest boundary whose own code links to it. Folding and lifting keep the concepts a view names.
10. **Cycles are detected.** `gloss check` reports an error for an `is-a` cycle, a `part-of` cycle (either tier) and a boundary `part-of` cycle, naming the members. Nothing hangs.
11. **Taxonomy-derived properties.** A concept that gives `is-a` instead of `kind` (which FILE-FORMATS.md allows) behaves like its ancestor's kind everywhere: `represents` on an entity subtype lifts to `holds`.
