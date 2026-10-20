# Hypothesis: `gloss suggest` confidence is calibrated well enough to auto-accept

## The question

GlossMark's plan (`GlossMark/docs/PLAN.md`, Phase 2 spec gate) targets **at least 80 % auto-accept at 90 % or better precision**. The mechanism is the `conf=` an agent or `gloss suggest` writes on every `@gloss?` proposal: the gate classes a proposal SOFT (auto-accept, audit later) when it is a valid link to an existing concept, inside the boundary's allowed set, changing only engineering views, and at or above `policy.soft-conf-threshold` (0.7 by default). QUICKSTART.md suggests "auto-accept SOFT; audit a random share weekly and calibrate `soft-conf-threshold` from agreement".

This experiment measures whether `conf=` from `gloss suggest` v0.1.0 means what the threshold assumes: that a proposal at 0.9 is right about nine times in ten, and that enough proposals clear the threshold to save a reviewer most of the work.

## Why it matters to an adopter

`gloss suggest` is step one of every adoption (adopt-glossmark skill). If its high-confidence proposals are reliable, a team can bulk-accept them and review only the tail. If they are not, the first patch either plants wrong links that look reviewed, or costs a full manual review, and the SOFT tier is a liability.

## What "GlossMark handles this well" would look like

1. **Precision rises with `conf`.** In the per-band table (`python3 calibrate.py`), precision in each band is at least the band's lower bound (a 0.9 band is at least 90 % correct), and is monotone in `conf`.
2. **The threshold works.** Proposals with `conf >= 0.7` have at least 90 % precision.
3. **The gate meets Phase 2.** Of all proposals, at least 80 % are SOFT in `gloss diff --base HEAD --format json` after `gloss suggest --write`, and the SOFT ones have at least 90 % precision.
4. **Proposals respect the boundary.** After `gloss suggest --write`, `gloss check` reports no GM503/GM502 (outside allowed set) and no GM131 (run of identical markers) that suggest itself introduced.
5. **Coverage of the vocabulary.** `suggest` proposes every relation a reviewer ends up writing for code it scans, and covers the file types the grammar supports (YAML, Markdown, workflows, Dockerfiles), or says it does not.
6. **The result is not one codebase's artefact.** Items 1 to 3 hold on two codebases in different domains and language mixes.

## Method

### Batches

| Batch | Codebase | How it was produced |
| --- | --- | --- |
| `clinic-booking` | `showcase/clinic-booking` (Go, TypeScript/TSX, Python, SQL, Terraform, YAML, Markdown) | Copy the workspace, delete every `@gloss` / `@gloss?` line from source files (ontology and manifests kept), delete `.glossmark/`, run `gloss suggest --format json`. |
| `meterworks` | `lab/confidence-calibration/meterworks/` (Java, Rust, Ruby, protobuf, SQL, YAML, Markdown), built for this lab | Code, ontology (core and impl tier) and manifests written by hand in one pass, **before** `gloss suggest` was ever run on it. The committed tree has no markers; `run.sh` runs suggest on it. Neither code nor ontology was edited after the first suggest run (bias control: the labeller wrote the code, so nothing was tuned towards or away from the matcher). |

### Labels (written before any proposal was read)

Each proposal is labelled by one reviewer (the lab author) against these rules. The question for every row: *would I accept this marker exactly as written, in this place?*

- **correct**: I would accept it unchanged. The declaration is a public surface a reader would look for (handler, model, table, page, test, resource), the relation is the one MARKING.md prescribes for that artifact, and the target is the concept the artifact is about. `.X` and `impl:X` (default namespace) are the same target. A different `conf` value does not matter.
- **near-miss**: the right artifact to mark, but the relation or the target is wrong (a model that should `consume` rather than `represent`; a page that `implements` the core process instead of its own impl concept; a test of the cancellation window marked `verifies Cancellation`). The reviewer keeps the line and edits it.
- **wrong**: the line should not exist. Either the declaration should not be marked at all (a private helper, one of a run of helpers that MARKING.md says get one marker or a `scope=block`, a test fake or fixture builder forced to `verifies` by the test-path rule, a DTO or wire type that only carries a concept, a package clause, a constant that is not a published value), or the concept is wrong (a stem or word collision: `booked` → Booking, `AppointmentReminding` for an appointment store).

Ties go to the stricter label. Each row carries a one-line reason.

A second label set comes from the clinic-booking coordinator's own review of the same 126 proposals (the KEEP map used when the showcase was adopted): kept with the same relation and target = correct; kept but changed = near-miss; dropped = wrong. These are derived mechanically, after my labels were frozen, and only used for inter-rater agreement (raw agreement and Cohen's kappa over three classes).

### Measures

- **Precision** = correct / all proposals in the band (near-miss counts as not correct: auto-accepting it writes a wrong link). `calibrate.py` also prints the lenient figure (correct + near-miss).
- **Bands**: `< 0.5`, `0.5-0.6`, `0.6-0.7`, `0.7-0.8`, `0.8-0.9`, `>= 0.9`, plus every distinct `conf` value (suggest emits only a handful of values: `conf = min(0.95, round(score/110, 2))` of a lexical search score).
- **Threshold**: precision of `conf >= 0.7` and its share of all proposals.
- **Gate**: AUTO/SOFT/HARD per proposal from `gloss diff --base HEAD --format json` in a temp git repo whose base commit is the stripped tree and whose working tree is the same after `gloss suggest --write` and `gloss build`. Auto-accept share = SOFT (+AUTO) / all; precision of the auto-accepted set from the labels.

All numbers are recomputed from `data/labels.csv` by `python3 calibrate.py`; `run.sh` regenerates the raw suggest and gate JSON from the code.

### Two manifest variants per codebase

Both codebases have one boundary with a written `allowed: [derived, ...]` (clinic-booking's reminder worker, meterworks' ingest service). `gloss suggest` reads that list differently from `gloss check` (F-CAL-2), so each batch is generated twice: with the manifests as committed, and with that one `allowed:` line removed. The second clinic-booking variant is exactly the coordinator's 126-proposal batch. Every distinct proposal from either variant is labelled once. `calibrate.py` reports both.

### Files

| Path | What it is |
| --- | --- |
| `meterworks/` | The second codebase: Rust meter ingest, Java (Spring Boot) billing, Ruby (Sinatra) portal, protobuf, SQL, Kubernetes YAML, a runbook and a workflow, with a core tier (`meter:`) and an implementation tier (`mw:`) written by hand. It carries **no markers on purpose**: it is the input to `gloss suggest`, and suggest skips declarations that are already marked. `.glossmark/` is current for that unmarked state; it has `graph.jsonl` and `context.jsonld` but no `ledger.jsonl`, because `gloss build` writes no ledger when there are no markers. At 62 files (about 40 of them source) it is larger than a minimal lab workspace: the sample needed enough declarations in each language to be worth labelling. |
| `data/*-suggest.json` | Raw `gloss suggest --format json` output, per codebase, committed manifests; `*-suggest-noallowed.json` is the variant without the written `allowed:` line. |
| `data/labels.csv` | One row per distinct proposal: `conf`, `band`, `label`, `reason`, `cause`, the coordinator's label (clinic-booking only), and the gate class with each manifest variant (empty when the proposal is absent in that variant). |
| `calibrate.py` | Recomputes every table in FINDINGS.md from `data/labels.csv` (stdlib only). |
| `run.sh` | Regenerates every batch and gate in temp copies, checks them against `data/`, prints the F-CAL-2 and F-CAL-6 repros, then runs `calibrate.py`. Writes nothing in the repository. |
