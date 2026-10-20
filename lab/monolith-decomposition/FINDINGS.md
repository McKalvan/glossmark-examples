# Findings: monolith decomposition

Every output below comes from the v0.1.0 binary (`$GLOSS`). `run.sh` reproduces all of them on temporary copies and leaves this directory untouched. `HYPOTHESIS.md` describes the snapshots.

## Verdict

v0.1.0 can describe **before** and **after** cleanly. It describes **during** only partly. Concept-level deprecation works well. Everything the in-between state is actually about is silent: two live implementations, a module due for deletion, and a deadline.

| # | Hypothesis item | Result | Evidence |
| --- | --- | --- | --- |
| 1 | All three states expressible | **Met.** `check` is clean on `before/` and `after/`. On `during/` it gives one intended GM222. | `run.sh`, first five sections |
| 2 | The overlap is visible | **Not met.** Two boundaries realizing `hire:Invoicing` and holding `hire:Invoice` are both "Consistent". `drift`, `landscape` and `diff` say nothing. | F-SPLIT-2 |
| 3 | Retirement is declarable | **Partly.** Concepts work: `deprecated` + `replaced-by`, GM222 at every marker, a HARD gate on new links. Boundaries cannot be marked at all (F-SPLIT-6). Dates cannot be attached (F-SPLIT-10). | F-SPLIT-6, F-SPLIT-10 |
| 4 | The diff tells a reviewer what moved | **Partly.** Every change is listed and correctly gated, but there is no per-concept summary of realizers. The base's file coverage is wrong. | F-SPLIT-5, F-SPLIT-12 |
| 5 | The namespace move follows semver | **Partly.** In one repository, cross-namespace `replaced-by` works, and removal is MAJOR with a hint. Deprecation is PATCH. A cross-repository `replaced-by` needs a reverse import. | F-SPLIT-8, F-SPLIT-9 |
| 6 | `landscape` helps across repositories | **Partly.** It unions both repositories, and cross-repo `part-of` works. It reports no overlap, and its arrows contradict its own header. | F-SPLIT-2, F-SPLIT-11 |
| 7 | A migration view works | **Partly.** A curated view shows old and new side by side at code zoom, and `view --diff` overlays a change. Neither the view nor the viewer data carries `deprecated` or `replaced-by`. | F-SPLIT-7 |
| 8 | Agents are steered | **Partly.** New links to a deprecated concept are HARD, and the briefing drops deprecated concepts. The briefing never says the directory is retiring. | F-SPLIT-13 |

Two of the findings are v0.1.0 bugs that reach well beyond migrations:

- **F-SPLIT-1.** Imported ontologies are recorded with absolute paths, so the committed graph of every importing repository changes per checkout.
- **F-SPLIT-3.** An imported implementation namespace defaults to the core tier, which silently switches off the published-seam rule (GM230).

**What worked well** (all reproduced by `run.sh`):

- GM222 fires on every marker that targets a deprecated concept and names the replacement: `generator.py:10: warning: hq:InvoiceGenerator is deprecated; use inv:InvoiceRun`.
- A new link to a deprecated concept is HARD with an explicit reason: `? implements hq:InvoiceGenerator ... [HIGH, agent, conf 0.90, HARD: target deprecated]`.
- Deprecated concepts with no code are not orphans and are left out of concept coverage. `after/` therefore stays clean while keeping the permanent IDs. In `during/`, coverage counts 3 of the 4 implementation concepts.
- `realizes: [inherit, hire:Booking]` on the monolith shrank by itself when the invoicing component was deleted, so the monolith's manifest needed no edit.
- Deleting a concept is HARD and MAJOR with the right advice: `concept hq:InvoiceGenerator removed; IDs are permanent, prefer deprecated: true + replaced-by:`.
- `gloss impact` on the legacy file is the single best migration aid in v0.1.0. It lists both boundaries that realize `hire:Invoicing`, both test files, and `! deprecated; use inv:InvoiceRun`.
- `part-of: bw:tool-hire` in the sibling repository's manifest puts the service into the monolith repository's system in `landscape`.
- An import cycle between the two sibling repositories, where each imports the other's namespace, is accepted by `check`, `lock` and `build` without complaint.

## F-SPLIT-1: graph.jsonl records imported ontologies with absolute paths

**Problem.** For every concept of an imported namespace, `gloss build` writes the absolute filesystem path of the source ontology into the node's `file` field and into `prov.path` of each declared edge. The committed graph therefore depends on where the repository was checked out. A rebuild in CI or in a colleague's checkout rewrites `graph.jsonl`. `gloss doctor` then reports `✗ graph: .glossmark/graph.jsonl is stale`, and any "the committed graph is current" CI check fails. It also leaks the author's home directory into a committed file. GlossMark's own example has the same problem: `examples/payments/settlement-worker/.glossmark/graph.jsonl` contains `"file":"/home/user/GlossMark/examples/payments/payments-api/ontology/pay.gloss.yaml"`.

**Repro.** `lab/monolith-decomposition/during-split/invoicing-service` imports `hire:` from `../hirehq/ontology/hire.gloss.yaml`.

```sh
cd lab/monolith-decomposition/during-split/invoicing-service
grep -o '"curie":"hire:Invoice","[^}]*' .glossmark/graph.jsonl | grep -o '"file":"[^"]*"'
# "file":"/home/ckessler/dev/glossmark-examples/lab/monolith-decomposition/during-split/hirehq/ontology/hire.gloss.yaml"
cp -r .. /tmp/elsewhere && cd /tmp/elsewhere/invoicing-service
$GLOSS doctor        # ✗ graph: .glossmark/graph.jsonl is stale: rebuilding from the tree gives a different graph
$GLOSS build -q
diff <committed graph.jsonl> .glossmark/graph.jsonl | grep -c '^>'     # 10 lines differ, only in the path prefix
```

**Proposed change.** Record an imported file's path relative to the workspace root, as written in `imports.<p>.source` (`../hirehq/ontology/hire.gloss.yaml`). Alternatively record the import prefix plus the path inside the source. Never write an absolute path into `graph.jsonl`, `ledger.jsonl` or `glossmark.lock`.

**Done when.** `grep -c "$PWD" .glossmark/graph.jsonl` prints 0 in `during-split/invoicing-service`, and a rebuild in a copy at another path leaves `graph.jsonl` byte-identical.

## F-SPLIT-2: two live implementations of one capability are silent

**Problem.** During a strangler migration, two boundaries realize the same core process and hold the same entity. That is the single most important fact about the state, and GlossMark reports nothing about it. It is neither a violation nor a duplication; it simply does not appear. `drift --all` lists both boundaries as consistent. `landscape` over the two sibling repositories does the same. `diff` from `before` to `during` mentions the new boundary but not that `hire:Invoicing` now has two realizers. Nothing lets a team say "this overlap is intended, and it ends when the old side is deleted". There is also nothing to express that a feature flag decides between the two sides. `configures` on the flag file is accepted, but the flag is only linked to the facade.

**Repro.**

```
cd lab/monolith-decomposition/during && $GLOSS drift --all
✓ Consistent
  bw:hirehq-invoicing holds {hire:Invoice} ⊑ declared {hire:Invoice}
  bw:hirehq-invoicing realizes {hire:Invoicing, hq:InvoiceGenerator, hq:InvoicingRouter} ⊑ declared {hire:Invoicing}
  ...
  bw:invoicing-service holds {hire:Invoice} ⊑ declared {hire:Invoice}
  bw:invoicing-service realizes {hire:Invoicing, inv:InvoiceRun} ⊑ declared {hire:Invoicing}
... Violations: 0   Gaps: 0 ...
cd ../during-split && $GLOSS landscape --repo hirehq --repo invoicing-service --all --fail-on none   # same lines, no finding
```

**Proposed change.**

1. Add an informational finding kind **`overlap`**, not failing by default. It fires when two boundaries, neither nested in the other, both realize the same concept or both hold the same entity, in one workspace or across a landscape. Example: `hire:Invoicing is realized by bw:hirehq-invoicing and bw:invoicing-service`.
2. Let a manifest declare the migration, which silences the overlap between the two named boundaries:

   ```yaml
   boundary: bw:hirehq-invoicing
   deprecated: true
   replaced-by: bw:invoicing-service
   retire-by: 2026-12-31
   ```

3. After `retire-by`, the overlap turns into a failing **`overdue`** finding on the retiring boundary.
4. Optionally, a `switch:` key on the retiring manifest can name the flag file, so the viewer can show what routes between the two sides.

**Done when.** `drift` on `during/` without the manifest keys prints one `overlap` line for `hire:Invoicing` and one for `hire:Invoice`. With the keys, it prints none. With `retire-by` in the past, `drift --fail-on overdue` exits 1. `landscape` on `during-split/` prints the same overlap across repositories.

## F-SPLIT-3: an imported implementation namespace is typed core unless the import says tier:, which is undocumented

**Problem.** An importer learns nothing about the tier of what it imports. Without a `tier:` key on the import entry, the namespace is recorded as `"tier":"core"`. That holds even when the source is the owner's `gloss publish` output, which says `inv: (implementation 0.1.0)` when it is written. As a result GM230 never fires. GM230 is the documented rule that "only **published** concepts of an imported implementation namespace are referenceable". A monolith can link straight to the new service's private `inv:InvoiceRun`. Writing `tier: implementation` on the import entry restores the rule, but FILE-FORMATS.md does not list that key for `imports:`.

**Repro.** In `lab/monolith-decomposition/during-split/hirehq`, add a marker `# @gloss implements inv:InvoiceRun` in a new file under `monolith/hirehq/invoicing/`. Add `inv:InvoiceRun` to that manifest's `allowed:`. Then compare the two import forms:

```
with tier: implementation on the import:
monolith/hirehq/invoicing/probe.py:1: error: inv:InvoiceRun is an unpublished concept of imported namespace inv: and cannot be referenced; only published concepts cross repos [GM230]
without it:
gloss check: 0 errors, 1 warning
"curie":"inv:InvoiceRun","ns":"inv","tier":"core"
```

**Proposed change.** Take the tier from the source. `gloss publish` already knows it, so write `tier:` into the published `<ns>.gloss.yaml` and `ontology.jsonld`. Accept an optional top-level `tier:` in any ontology file. When neither the source nor the import states a tier, warn that the published seam is not enforced for that namespace. Document `tier:` under `imports:`.

**Done when.** The repro without `tier:` on the import, importing from `gloss publish` output, reports GM230. FILE-FORMATS.md lists `tier` under `imports.<prefix>`.

## F-SPLIT-4: rewriting a core concept's definition passes the HARD gate

**Problem.** ADVANCED.md says HARD covers "any ontology or manifest edit". In v0.1.0 a change that only touches `doc:` or a label is SOFT, unless the concept is published. That holds for core concepts too. An agent can redefine a business process, here from "invoiced on return" to "invoiced weekly in advance", without bumping any version. The default PR gate (`--fail-on HARD`) passes, and "Views changed: none" is reported although the business view shows that definition. Inconsistently, a version-only change to an ontology file in the same tree is HARD (`! ontology/inv.gloss.yaml changed [HARD: edit to ontology/ or manifests]`, in the `during` to `after` diff). The migration relies on prose in `doc:`, such as "Being retired: ...", so this matters here. The version-evolution lab probes the published-concept side of the same rule.

**Repro.**

```
# copy lab/monolith-decomposition/before to a temp git repo, commit, then:
sed -i 's|doc: "A returned hire is priced by the day and invoiced to the customer."|doc: "A hire is invoiced to the customer weekly in advance, whether or not it has been returned."|' ontology/hire.gloss.yaml
$GLOSS build -q && $GLOSS diff --base HEAD --fail-on HARD; echo "exit=$?"
Ontology impact — ...   base HEAD   gate SOFT   criticality high
! hire:Invoicing label/doc                                     ontology/hire.gloss.yaml:23   [HIGH, SOFT]
! namespace hire: changes require a PATCH bump but version went 1.0.0 → 1.0.0 (none)   ontology/hire.gloss.yaml      [SOFT]
Views changed: none
exit=0
```

**Proposed change.** Make a `doc:` or label change on a **core** concept HARD and count it as a change to every view that includes the concept. Keep implementation-concept doc edits SOFT if that is the intent, and say so in ADVANCED.md's gate list. Either way, apply `hard-paths` (default `ontology/**`) consistently: a semantic change classification must not lower a path-based HARD.

**Done when.** The repro prints `gate HARD`, lists `Views changed: business`, and exits 1.

## F-SPLIT-5: gloss diff lists the parts of a move but never says what moved

**Problem.** On the PR that introduces the service, a reviewer gets twelve correct, correctly gated lines. Nowhere do they read "`hire:Invoicing`: realized by `bw:hirehq-invoicing` → `bw:hirehq-invoicing`, `bw:invoicing-service`". The rollup line lists every boundary, unchanged ones included, as `✓`. On the PR that deletes the old module, the cutover is the moment `hire:Invoicing` loses its last monolith implementation and `hire:Invoice` moves to a new store. That appears only as per-link removals gated SOFT. The overall gate is HARD only because a manifest was deleted. The same diff also reports "Views changed: none" although it deletes the curated `invoicing-migration` view.

**Repro.** `run.sh`, sections "F-SPLIT-5: diff before -> during" and "diff during -> after". Trimmed:

```
! boundary bw:invoicing-service added (container)            services/invoicing/.gloss.yaml       [HIGH, HARD: edit to manifest]
+ implements inv:InvoiceRun                                  services/invoicing/internal/invoice/run.go:Service.Issue   [HIGH, agent, SOFT]
+ represents hire:Invoice                                    services/invoicing/migrations/0001_invoices.sql:table.invoices   [HIGH, agent, SOFT]
Views changed: engineering, invoicing-migration      Rollup: bw:hirehq-invoicing holds {hire:Invoice} ⊑ declared  ✓; ... (6 boundaries)
---
- boundary bw:hirehq-invoicing removed                      monolith/hirehq/invoicing/.gloss.yaml   [HIGH, HARD: edit to manifest]
- implements hq:InvoiceGenerator removed                    monolith/hirehq/invoicing/generator.py:generate_invoice   [HIGH, SOFT]
- represents hire:Invoice removed                           monolith/hirehq/invoicing/models.py:Invoice   [HIGH, SOFT]
Views changed: none
```

**Proposed change.** Add a **Realization changes** block to `diff` (text, markdown and JSON). For each concept whose set of realizing or holding boundaries changed, print one line: `hire:Invoicing realized by {bw:hirehq-invoicing} → {bw:hirehq-invoicing, bw:invoicing-service}` and `hire:Invoice held by {bw:hirehq-invoicing, bw:invoicing-service} → {bw:invoicing-service}`. Gate a change that removes a boundary's last realization of a `high` or `critical` concept at the concept's criticality gate, rather than SOFT. List removed views under "Views changed".

**Done when.** `run.sh`'s two diffs each print a "Realization changes" block with the lines above, and the `during` to `after` diff lists `invoicing-migration` as changed.

## F-SPLIT-6: a boundary cannot be marked as retiring, and an unknown manifest key drops the whole boundary

**Problem.** Concepts have `deprecated`/`replaced-by`; boundaries have nothing. Writing the obvious keys on the retiring module's manifest is GM110, and that part is fine. The real problem is that the whole manifest is then discarded. Its markers fall through to the parent, which reports them as GM503, and `drift` reports four **violations** on `bw:hirehq`, none of which exists. One error in one file becomes a failing build that blames another boundary. The GM110 message also prints the absolute path and points at line 1.

**Repro.** Append three lines to `lab/monolith-decomposition/during/monolith/hirehq/invoicing/.gloss.yaml` on a copy:

```
monolith/hirehq/invoicing/.gloss.yaml:1: error: /tmp/.../monolith/hirehq/invoicing/.gloss.yaml: yaml: unmarshal errors:
  line 8: field deprecated not found in type model.Manifest
  line 9: field replaced-by not found in type model.Manifest
  line 10: field retire-by not found in type model.Manifest [GM110]
monolith/hirehq/invoicing/models.py:6: warning: represents hire:Invoice is outside the allowed set derived from monolith/.gloss.yaml (HARD gate); ... [GM503]
monolith/hirehq/invoicing/tests/test_generator.py:8: warning: verifies hire:Invoicing is outside the allowed set derived from monolith/.gloss.yaml (HARD gate); ... [GM503]
... Violations: 4 ...
gloss drift: 4 failing findings (violation,value-drift,gap,dangling)
```

**Proposed change.** Add `deprecated`, `replaced-by` (a boundary) and `retire-by` (a date) to the manifest schema, with the semantics in F-SPLIT-2. Separately, decode manifests leniently: report each unknown key as GM110 at its own line with a workspace-relative path, then keep the known keys, so the boundary still exists.

**Done when.** The repro with the keys passes `check` and the boundary node carries `deprecated` and `replaced-by`. With a misspelt key (`realises:`), `check` reports GM110 at that line and `drift` reports no violations on the parent.

## F-SPLIT-7: deprecation and replacement are invisible in views and the viewer

**Problem.** A migration view is the natural place to show old next to new. The curated view in `during/ontology/views.yaml` gets close: at code zoom it shows both boundaries, the three implementation concepts and their artifacts. But `replaced-by` is stored as a node attribute, not an edge, so `relations: [replaced-by]` selects nothing. The view nodes and the viewer's concept panel carry neither `deprecated` nor `replaced-by`. A reader cannot tell the old implementation from the new one. `views.yaml` also cannot select by property. An unknown key such as `where:` aborts `gloss check` outright rather than reporting a diagnostic.

**Repro.**

```
cd lab/monolith-decomposition/during && grep -c '"p":"replaced-by"' .glossmark/graph.jsonl      # 0
$GLOSS view --json -o /tmp/v.json   # then, for the invoicing-migration view:
view nodes with a deprecated key: 0
view edge predicates: ['configures', 'holds', 'implements', 'produces', 'realizes', 'represents', 'verifies']
concept panel keys for hq:InvoiceGenerator: ['artifacts', 'realizes']
```

**Proposed change.** Emit `replaced-by` as a declared edge (`hq:InvoiceGenerator replaced-by inv:InvoiceRun`) so views can select and draw it. Carry `deprecated` and `replaced-by` on view nodes and in the concept panel, and draw deprecated nodes struck through or dashed. With F-SPLIT-6, do the same for boundaries. A migration view would then read:

```yaml
invoicing-migration:
  include: [hire:Invoicing, hire:Invoice, hq:InvoiceGenerator, hq:InvoicingRouter, inv:InvoiceRun]
  relations: [realizes, holds, replaced-by]
  zoom: code
```

Report unknown view keys as a `check` diagnostic with a line number instead of aborting.

**Done when.** In `during/`, the graph has one `replaced-by` edge per deprecated concept. The `invoicing-migration` view JSON has `deprecated: true` on `hq:InvoiceGenerator` and a `replaced-by` edge.

## F-SPLIT-8: a rename into a sibling repository's namespace needs a reverse import, and the two diagnostics disagree

**Problem.** When the service lives in its own repository, `replaced-by: inv:InvoiceRun` in the monolith's `hq:` fails GM341 ("does not exist"). Meanwhile GM222 on the same concept tells every caller to "use inv:InvoiceRun". The only way to make it resolve is for the monolith to import the service's namespace, which is what `during-split/hirehq/glossmark.yaml` does. That creates an import cycle, since the service already imports `hire:` from the monolith, and the dependency points the wrong way: the old code depends on the new code's ontology only to name its successor. The reference also bypasses the published seam: `replaced-by` resolves to the unpublished `inv:InvoiceRun` with no GM230, even with `tier: implementation`.

**Repro.** Remove the `imports:` entry from a copy of `lab/monolith-decomposition/during-split/hirehq/glossmark.yaml`:

```
monolith/hirehq/invoicing/generator.py:10: warning: hq:InvoiceGenerator is deprecated; use inv:InvoiceRun [GM222]
ontology/hq.gloss.yaml:9: error: hq:InvoiceGenerator: replaced-by inv:InvoiceRun does not exist [GM341]
```

**Proposed change.** Let `replaced-by` name a full IRI, or a CURIE whose prefix is declared under `prefixes:`, without importing it. Check it with GM341 only when the namespace is owned or imported. Otherwise defer the check to `gloss landscape`, which sees both repositories and can report a dangling replacement there. GM222 should print the replacement only once it resolves, and say "replacement unresolved" when it does not.

**Done when.** With `inv: https://onto.brightwater.example/inv/` under `prefixes:` and no import, `check` in `during-split/hirehq` reports no error, and `landscape` over both repositories reports a dangling `replaced-by` if `inv:InvoiceRun` is renamed in the service.

## F-SPLIT-9: deprecation is classified PATCH

**Problem.** `gloss diff` classifies `deprecated: false → true` as requiring a PATCH bump. The semver specification's FAQ says a deprecation should ship in a MINOR release ("before you completely remove the functionality in a new major release there should be at least one minor release that contains the deprecation"). A downstream range like `~1.0.0` therefore picks up deprecations as fixes. VERSIONING.md's table does not mention deprecation. The version-evolution lab measures the same classification from the importer's side ([F-VER-9](../version-evolution/FINDINGS.md#f-ver-9-deprecation-alone-is-classified-patch)).

**Repro.** Copy `before/` to a temp git repository, commit, add `deprecated: true` and `replaced-by: hq:BookingView` to `hq:InvoiceGenerator`, and rebuild:

```
! hq:InvoiceGenerator deprecated false → true                  ontology/hq.gloss.yaml:9   [HIGH, HARD: edit to ontology]
Version hq: 1.0.0 → 1.0.0 (requires PATCH) ✗
```

**Proposed change.** Classify a deprecation, and any change to `replaced-by`, as MINOR. Add a row to VERSIONING.md's table.

**Done when.** The repro prints `requires MINOR`.

## F-SPLIT-10: waivers cannot carry a retirement deadline, and dead waivers are silent

**Problem.** `policy.waivers` is the only dated object in GlossMark, so it is the natural place for "the legacy module goes by 31 December". It cannot be used for that. A waiver only silences a drift finding, and nothing in the migration is a drift finding (F-SPLIT-2). A waiver naming `hq:InvoiceGenerator` leaves its GM222 `check` warning in place. A waiver for a concept with no finding, an expired waiver, and a waiver naming a concept that does not exist (`bogus:Nothing`) all produce no output at all.

**Repro.** Add three waivers to a copy of `lab/monolith-decomposition/during/glossmark.yaml`: one in the future for `hq:InvoiceGenerator`, one expired for `hq:InvoicingRouter`, and one for `bogus:Nothing`. `run.sh` section F-SPLIT-10:

```
monolith/hirehq/invoicing/generator.py:10: warning: hq:InvoiceGenerator is deprecated; use inv:InvoiceRun [GM222]
gloss check: 0 errors, 1 warning
0          # lines of drift output that mention a waiver
```

**Proposed change.** Make `check` warn on a waiver that matches no current finding and on an expired waiver. Use the manifest's `retire-by` from F-SPLIT-2 for deadlines rather than overloading waivers.

**Done when.** The repro prints one warning per waiver: two "matches nothing" and one "expired 2026-01-31".

## F-SPLIT-11: landscape's context map contradicts its own header

**Problem.** The header reads `Context map (publishes → subscribes, produces → consumes across boundaries)`, but each arrow points from the consumer to the producer, which is the `depends-on` direction from GRAPH.md. In `during-split`, `bw:invoicing-service → bw:hirehq via hire:Hire` reads as "the service produces hires for the monolith", which is backwards. GlossMark's own payments example shows the same: `acme:settlement-worker → acme:payments-api via pay:CaptureConfirmed, pay:Payment`, although payments-api publishes that event. Separately, when the sibling service joins the system with `part-of: bw:tool-hire`, the context map gains `bw:tool-hire → bw:hirehq via hire:Hire`: a system depending on its own container.

**Repro.**

```
cd lab/monolith-decomposition/during-split && $GLOSS landscape --repo hirehq --repo invoicing-service --fail-on none
Context map (publishes → subscribes, produces → consumes across boundaries)
  bw:hirehq-invoicing → bw:hirehq via hire:Hire
  bw:invoicing-service → bw:hirehq via hire:Hire
# with part-of: bw:tool-hire appended to invoicing-service/.gloss.yaml:
  bw:tool-hire → bw:hirehq via hire:Hire
```

**Proposed change.** Either print `consumer → producer (depends on)` in the header, or flip the arrows to match it. Drop context-map edges between a boundary and its own ancestor or descendant.

**Done when.** The header and the arrow agree on GlossMark's payments example, and the `part-of` repro prints no `bw:tool-hire →` edge.

## F-SPLIT-12: diff computes the base's file coverage over the head's file set

**Problem.** The `Files X% → Y%` figure in `gloss diff` divides the base's covered files by the head's in-scope file count. Adding files therefore lowers the base's percentage. In the `before` to `during` diff, the base shows 28% (5 of 18), although `drift` on `before/` says 50% (5 of 10). That makes the comparison meaningless on exactly the PRs that add a service.

**Repro.** Copy `before/` to a temp git repository, commit, add five unmarked `.py` files, and rebuild:

```
drift at the base:  Files 50% (5/10)
diff:               Files 33% → 33%
```

**Proposed change.** Compute the base's file coverage from the base tree's own file set, as `drift` does on a checkout of the base.

**Done when.** The repro prints `Files 50% → 33%`.

## F-SPLIT-13: the agent briefing in a retiring module does not say it is retiring

**Problem.** `gloss context --dir monolith/hirehq/invoicing` correctly drops the deprecated `hq:InvoiceGenerator` from the vocabulary. But it does not tell the agent that the code here is being retired, or that `inv:InvoiceRun` in `bw:invoicing-service` replaces it. An agent asked to "add credit notes to invoicing" will extend the legacy module, where `hq:InvoicingRouter` is still offered as a target. It only learns otherwise when the HARD gate stops the PR.

**Repro.**

```
cd lab/monolith-decomposition/during && $GLOSS context --dir monolith/hirehq/invoicing
Boundary: bw:hirehq-invoicing (component); `.Name` = `hq:Name`; realizes hire:Invoicing; criticality high (inherited from hire:Invoice)
Concepts (4, most relevant to this directory first):
- hire:Invoice ... - hire:Invoicing ... - hq:InvoicingRouter ... - hq:BookingView ...
```

**Proposed change.** When the directory's code links to deprecated concepts, add one line: `Retiring here: hq:InvoiceGenerator → inv:InvoiceRun (bw:invoicing-service). Do not add links to deprecated concepts.` With F-SPLIT-6, use the boundary's own `deprecated`/`replaced-by`/`retire-by` for this line.

**Done when.** The repro's briefing contains the "Retiring here" line naming `inv:InvoiceRun`.
