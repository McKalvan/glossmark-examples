# Hypothesis: monolith decomposition

## The question

Can GlossMark's ontology and manifests describe a codebase **before**, **during** and **after** a strangler-fig split? During the split a monolith module and a new service both implement the same capability, and a feature flag decides which one serves the traffic.

## Why it matters

Most adopters are mid-migration, not greenfield. The in-between state is where a code map earns its keep. A reviewer needs to know which of two implementations is authoritative and what is due to be deleted. An agent needs to know not to extend the old path. Without that, the graph is right only before and after the migration, which is when nobody needs it.

## The system

Brightwater Tool Hire rents equipment. Its Django monolith `hirehq` does bookings and invoicing. Invoicing is being moved into a Go service.

| Snapshot | Shape | What it holds |
| --- | --- | --- |
| `before/` | one workspace | `hirehq` with a `bw:hirehq-invoicing` component; namespaces `hire:` (core) and `hq:` (monolith) |
| `during/` | one workspace, same paths | adds `services/invoicing` (`bw:invoicing-service`, namespace `inv:`), a strangler facade `hq:InvoicingRouter` behind the waffle switch `invoicing.use_service`, and `hq:InvoiceGenerator` marked `deprecated` with `replaced-by: inv:InvoiceRun`; adds a curated `invoicing-migration` view |
| `after/` | one workspace, same paths | the monolith invoicing module and its manifest are gone; `hq:InvoiceGenerator` and `hq:InvoicingRouter` stay as deprecated entries, because concept IDs are permanent |
| `during-split/` | two sibling repositories | `hirehq/` owns `hire:` and `hq:`; `invoicing-service/` imports `hire:` and owns `inv:`; `hirehq` imports `inv:` back so `replaced-by` can name the replacement |

The three monorepo snapshots share paths, so `run.sh` can commit one snapshot in a temp git repository, lay the next over it and run `gloss diff --base HEAD`. That is what a reviewer sees on the migration's pull requests.

## What "handles this well" looks like

1. **All three states are expressible.** `gloss check` passes on each snapshot. The only warnings are ones the migration intends.
2. **The overlap is visible.** In `during/`, two boundaries that realize `hire:Invoicing` and hold `hire:Invoice` produce something in `gloss drift`. It should not be a violation, but it should be a named, waivable finding that says "two implementations". A team can declare the overlap intended.
3. **Retirement is declarable.** A concept can be marked deprecated with a replacement, and code that links to it is flagged. A *boundary* can be marked as retiring, with the boundary that replaces it and a date. A date in the past turns into a failing finding.
4. **The diff tells a reviewer what moved.** `gloss diff` from `before` to `during` says that `hire:Invoicing` gained a second implementation in `bw:invoicing-service`. From `during` to `after` it says that `bw:hirehq-invoicing` stopped realizing it. The coverage numbers are right for both states.
5. **The namespace move follows semver.** Deprecating `hq:InvoiceGenerator` in favour of `inv:InvoiceRun` asks for a MINOR bump, as semver.org's FAQ prescribes for deprecations. Deleting the concept asks for a MAJOR bump. `replaced-by` can name a concept in a sibling repository's namespace without contortions.
6. **`landscape` helps across repositories.** Over the two sibling repositories it reports that both realize `hire:Invoicing`. The service can join the `bw:tool-hire` system, and the context map shows the dependency in a readable direction.
7. **A migration view works.** A curated view in `views.yaml` shows old and new side by side, marks the deprecated concepts, and draws `replaced-by` as an edge. `gloss view --diff` can overlay a change.
8. **Agents are steered.** New links to a deprecated concept are gated. The briefing for the retiring directory says it is retiring and names the replacement.

`FINDINGS.md` checks each item against v0.1.0. `run.sh` reproduces every output it quotes.
