# Hypothesis: version evolution

## Question

When one repository owns a shared namespace and others import it at pinned ranges, does GlossMark v0.1.0 tell each party the right thing at each release? The releases go PATCH (labels, docs, values), MINOR (additions) and MAJOR (removal, retype, is-a or part-of change), per GlossMark's `docs/VERSIONING.md`. The tools under test are `gloss diff` in the owner, `gloss check` (GM105 to GM109), `gloss lock` and `gloss drift` in each importer, and `gloss landscape` across all of them.

## Why it matters

A shared core namespace is the whole point of the two-tier model. Once three teams import it, every upstream edit is a release, and the failure modes are the ones every package ecosystem already has:

- the owner forgets to bump;
- the owner bumps by the wrong amount;
- an importer's range lets a breaking change in;
- an importer silently runs against a version its range forbids;
- a concept disappears with no warning.

If GlossMark's versioning only works when everyone does the right thing, the lockfile and ranges are ceremony.

## Setup

Four sibling workspaces, wired with relative-path imports and committed `glossmark.lock` files:

| Workspace | Role | Imports | Range | References |
| --- | --- | --- | --- | --- |
| `meter-core/` (Go) | Owner of core `grid:` and implementation `mc:`. `mc:ReadingFeed` is published as `grid:MeterReading`. | | | |
| `billing/` (Python) | Importer that re-certifies on every minor release | `grid` | `~1.0.0` | `grid:Customer`, `grid:Billing` |
| `outage-map/` (TypeScript) | Importer that follows major 1 | `grid`, `mc` | `^1.0`, `1.x` | `grid:Outage` (deprecated, then removed), `mc:ReadingFeed` (published) |
| `analytics/` (SQL) | Importer that accepts anything below 3.0 | `grid` | `>=1.0 <3.0` | `grid:Tariff` (retyped), `grid:SmartMeter` (is-a changed), `grid:Outage` (removed) |

`run.sh` copies the four into a temporary git repository and releases `grid` as 1.0.1 (doc), 1.1.0 (add), 1.2.0 (add plus deprecate with `replaced-by`) and 2.0.0 (remove, retype, is-a change). After each release it records the owner's `gloss diff --base HEAD`, then in each importer `check`, `lock`, `check`, `drift`, and finally `gloss landscape` over all four. Failure cases branch off a release and are reverted:

- a doc change with no bump;
- the bump written in `glossmark.yaml` and not in the ontology file;
- a MINOR declared for a removal, a retype and an is-a change;
- a published implementation concept withdrawn;
- a reference to a never-published implementation concept;
- a deleted lock, a lock from a newer format, and an unversioned import.

The output is [TRANSCRIPT.md](TRANSCRIPT.md).

## What "GlossMark handles this well" looks like

Each item names the observable it is checked against.

1. **Classification.** `gloss diff` prints `requires PATCH` for a doc change and for a deprecation, `requires MINOR` for an addition, and `requires MAJOR` for a removal, a retype, an is-a change and a withdrawn `published:`. The `Version` line shows ✓ when the declared bump is large enough and ✗ when it is not.
2. **Missing or undersized bump fails the owner's gate.** A doc change with no bump, or a MINOR declared for a MAJOR change, makes `gloss diff` exit non-zero under its default `--fail-on HARD`, before any importer sees it.
3. **"Upstream forgot to bump" is caught downstream.** With the version unchanged and the content changed, every importer's `gloss check` reports GM107 naming the same-version content change.
4. **Ranges are enforced and a lock never records a forbidden version.** An importer whose range excludes the new release gets GM106. `gloss lock` refuses (non-zero exit), or at least warns, rather than pinning a version outside the range.
5. **One source of truth for a namespace's version.** `owns.<prefix>.version` in `glossmark.yaml` and `version:` in the ontology file either agree or `gloss check` says they do not. `diff` and importers read the same one.
6. **Deprecation warns importers before removal.** After `deprecated: true` + `replaced-by:`, `gloss check` in every importer that references the concept warns and names the replacement, in markers, manifests and ontology files alike.
7. **Removal breaks loudly where it is referenced.** An importer that still references a removed concept fails `check` and `drift` (dangling) for every reference, and `landscape` lists them all.
8. **The published-only rule holds.** An importer can reference only published concepts of an imported implementation namespace. Withdrawing `published:` makes the importer fail.
9. **The landscape shows version skew.** `gloss landscape` reports per importer the range, the locked version and the resolved version. It flags importers that are out of range, have a stale lock, or reference deprecated concepts.
10. **Lockfile hygiene diagnostics fire.** A deleted lock gives GM108, a lock with a newer `format:` gives GM109, and an unversioned import gives GM105.
11. **A retype is explained where it bites.** When a concept an importer `holds` is retyped so the importer's markers no longer lift, the finding says the concept's kind changed.
12. **Determinism.** The same steps give byte-identical output on every run, so the transcript can be committed and diffed.
