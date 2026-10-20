# Plan and progress log

Companion repository to [GlossMark](https://github.com/McKalvan/GlossMark), pinned to **v0.1.0**.
Two purposes: a **showcase** of GlossMark on stacks bigger than the toy examples in the main repo, and a **lab** whose every rough edge becomes written evidence for a GlossMark issue.

## Ground rules this repo follows

- Every command runs with the released v0.1.0 binary, installed by `scripts/install-gloss.sh` into `.tools/bin` (gitignored). `/usr/bin/gloss` on the authoring machine is an unrelated program, so nothing calls a bare `gloss` from `PATH` locally; the scripts use `$GLOSS` (default `.tools/bin/gloss`).
- Imports are local paths. Multi-repo examples are sibling directories, wired with relative paths and pinned with `gloss lock`.
- Every workspace sets `grammar: 1`. CI pins `mckalvan/glossmark@v0.1.0` and `version: v0.1.0`. `glossmark.lock` and `.glossmark/{graph,ledger}.jsonl` are committed.
- Code is realistic and inert: syntactically valid, never built, no dependencies installed.
- Markers follow `docs/MARKING.md` and the adopt-glossmark skill. Links were written by an agent (`GLOSS_ACTOR=agent:claude-code`); the ledgers say so.

## Domains and stacks

| Example | Domain | Shape | Stack |
| --- | --- | --- | --- |
| `showcase/clinic-booking` | Outpatient clinic appointment booking (Larkspur Clinics) | Monorepo web product | Next.js/TypeScript web, Go booking API, Python reminder worker, Postgres migrations, Terraform (AWS), Kubernetes, GitHub Actions |
| `showcase/freight-federation` | Freight shipping: shipments, dispatch, tracking | Three sibling repos sharing one core | `shipment-core` Java/Spring (owns core `frt:` + impl `shc:`), `dispatch` TypeScript/Node, `tracking` Rust |
| `showcase/claims-events` | Property and motor insurance claims | Event-driven system | Kafka topics, Avro schemas in a schema registry, Kotlin intake, Python assessment, Go payout notifier, AsyncAPI contract |
| `showcase/kitchen-agents` | Restaurant ordering and kitchen display, maintained by agents | Agent-heavy repository | Python FastAPI + TypeScript display; AGENTS.md, CLAUDE.md, skills, three subagents with remits |
| `showcase/library-legacy` | Municipal library circulation system, 15 years old | Brownfield adoption | Java servlets, Perl/shell batch jobs, SQL, YAML, Dockerfile, HCL, protobuf, JSON config, a Markdown glossary and an enums file |

## Matrix ownership

Each row of the README feature matrix is owned by at least one example. The owner is the example built to show it; others may show it too.

| Area | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | --- | --- | --- | --- | --- |
| Inline relations | implements, represents, presents, hosts, verifies, documents, provisions, configures, deploys, publishes-value | verifies, documents | produces, consumes, publishes, subscribes | instructs, may-modify | verifies alias `tests` (GM240), represents on SQL/proto |
| Ontology relations | presents, hosts, part-of | published-as, is-a/part-of extension across repos, has-part | produces, consumes, publishes, subscribes, is-a (deep), constrains, reverses, attaches-to, custom `relations:` | | deprecated/replaced-by |
| Manifest relations | realizes (incl. `inherit`), holds, presents, hosts, part-of, `allowed: [derived, ...]` | realizes, produces, consumes, publishes, subscribes | publishes, subscribes, produces, consumes (range-lcs rollup) | `allowed:` written list | has-part |
| Scopes | none, file, symbol | | block | | line, block, symbol, range (JSON Pointer sidecar), file |
| Marker keys | | | | conf, note, id | scope |
| Findings | orphan, untested, presented-only | cross-repo drift in landscape | violation, gap, value-drift, dangling | rogue, proposed, stale | waiver silences a gap |
| Gates | AUTO, SOFT (diff script) | HARD on a published concept | | HARD (out-of-remit, below threshold), SOFT (above threshold) | |
| Concept kinds | entity, process, capability, measure, constraint, resource, system-type | event | event, entity taxonomy | | |
| Review states | | | | proposed, accepted, rejected, stale, removed | |
| CLI | init, suggest, criticality, build, check, drift, coverage, view, export, impact, version | lock, publish, landscape, diff | | hook, agents, mcp, context, propose, accept, reject, status | import, export --status, doctor |

`depends-on`, `calls`, `derived-from` and `same-as` are derived or reserved and cannot be written by hand in v0.1.0; the matrix records where `depends-on` shows up (landscape) and names the other three as uncoverable.

## Conventions settled by the first example

Settled on `clinic-booking`; CONTRIBUTING.md has the contract.

1. **Golden files.** Each workspace root holds `expected-check.txt` and `expected-drift.txt` (multi-repo examples also `expected-landscape.txt`). `scripts/check-workspace.sh` runs check, `drift --fail-on <kinds>`, both golden diffs, and a rebuild that must not change `graph.jsonl` or `ledger.jsonl`. `UPDATE=1` rewrites the goldens. Drift output is relative-path and stable across runs; the trailer goes to stderr and is not part of the golden.
2. **Registry.** `showcase/workspaces.tsv` and `showcase/landscapes.tsv` are the one list both CI and `scripts/ci-local.sh` read. The script rejects unknown `--fail-on` kinds because v0.1.0 ignores them (F-ADOPT-11).
3. **Adoption order.** Code with no GlossMark files; `init --dry-run`; `init` with prefix overrides; delete `init`'s workspace-level workflow and hook files (except in kitchen-agents); move manifests onto deployables; tiers by hand; `suggest --write`; prune and retarget with a reviewed keep-list; hand-write what `suggest` cannot see; `criticality suggest`; `accept --policy`, then `accept --all`.
4. **The scope=file accept bug.** Accepting a `scope=file` proposal makes it stale at once (F-ADOPT-8). Until it is fixed, file-scope markers in showcase examples are recorded as written-accepted: after `accept --all`, the stale ledger lines are dropped and `gloss build` re-records them.
5. **Two-state demos** live in `demo/` and copy the workspace into a temporary git repository; `demo/tour.sh` is a read-only tour of the commands an example owns.
6. **Prefixes.** Short and readable (`clinic:`/`lark:`), never `init`'s initials.

## Build order

1. Skeleton: PLAN, README stub, CONTRIBUTING, install script, CI scripts, both workflows.
2. `clinic-booking` end to end: codebase without GlossMark, adoption as a new user, advanced features, documented drift, golden files, CI green locally.
3. The other four showcase examples, same recipe.
4. Seven lab experiments plus `lab/ADOPTION-LOG.md`.
5. README matrix filled and verified; final report below.

## Progress log

- 2026-10-19: skeleton committed.
- 2026-10-19: `clinic-booking` done: 87 source files across Next.js, Go, Python, SQL, Terraform, Kubernetes and Actions; 53 links; 0 violations, 0 gaps; documented orphan, presented-only and five untested; AUTO/SOFT/HARD and value-drift shown by `demo/gates.sh`. Adoption hit 21 friction points (C1 to C21), three of them v0.1.0 bugs (doctor PATH check, suggest text truncation, scope=file stale on accept).
- 2026-10-19: read GlossMark docs at v0.1.0 (identical to `main` at `5d20c47` for docs, action and skill). Installed v0.1.0. Probed: `check` and `drift` are read-only; drift's trailer goes to stderr; drift output is stable across runs; `build` rewrites only the generator line of a graph built by another version; `gloss init` in a subdirectory writes its own `.github/workflows/gloss.yml` and hook files; `coverage --fail-under current` needs `origin/main`.
- 2026-10-19: `claims-events` done: Kafka/Avro/AsyncAPI with Kotlin, Python and Go; documented violation, gap, value-drift, three orphans and one untested; dangling shown by `demo/dangling.sh` because it is a `check` error (GM215). Adoption rows E1 to E24.
- 2026-10-19: `kitchen-agents` done: FastAPI and a TypeScript kitchen display maintained by three subagents with `may-modify` remits; every review state in the ledger (removed in `demo/review.sh`), HARD out-of-remit gate, kept hook files, MCP server driven over stdio. Adoption rows K1 to K25. Feature-matrix registry and checker added.
- 2026-10-19: `library-legacy` done: Java servlets, Perl, shell, Ruby, SQL, protobuf; adopted through the glossary and enum importers; deprecated concept with `replaced-by`, a waived gap, every scope including JSON sidecar ranges, the `tests` alias, the coverage ratchet (`current` in the registry, because the policy key rejects it). Adoption rows L1 to L32.
- 2026-10-19: lab experiments done: ambiguous-surfaces (F-SURF-1..11), concept-poor-legacy (F-POOR-1..7), confidence-calibration (F-CAL-1..7), cross-cutting-concerns (F-XCUT-1..10), deep-hierarchies (F-DEEP-1..11), monolith-decomposition (F-SPLIT-1..13), version-evolution (F-VER-1..11). Every `run.sh` exits 0 and leaves the tree unchanged.
- 2026-10-19: `scripts/check-workspace.sh` normalises the checkout prefix before comparing graphs, because importer graphs record absolute paths (F-SPLIT-1). Verified by running `scripts/ci-local.sh` from a copy at another path.
- 2026-10-19: `freight-federation` done: shipment-core (Java), dispatch (TypeScript), tracking (Rust) as sibling workspaces with semver-ranged local imports and `glossmark.lock`; landscape golden; HARD gates on a published value and a MAJOR bump; `gloss publish`. Adoption rows FF1 to FF22.
- 2026-10-19: README index and feature matrix rendered; `showcase.yml` runs `scripts/feature-matrix.py --check`.

## Final report

### What exists

| Area | Content |
| --- | --- |
| Showcase | 5 examples, 7 workspaces, about 560 files. `scripts/ci-local.sh` prints `ok` for every workspace and the landscape, also from a copy at another path |
| Lab | 7 experiments, 70 issue-ready findings, each with a `run.sh` that exits 0 |
| Adoption | 136 friction rows in [lab/ADOPTION-LOG.md](lab/ADOPTION-LOG.md), distilled into F-ADOPT-1..12 in [lab/FINDINGS-ADOPTION.md](lab/FINDINGS-ADOPTION.md) |
| CI | `showcase.yml` (matrix from the registry, Action where possible, golden checks, landscape, matrix check) and `lab.yml` (weekly, `continue-on-error`). Neither has run on GitHub yet: nothing was pushed |

### Feature matrix

121 of 125 rows have evidence in at least one example, and `scripts/feature-matrix.py --check` verifies every cited file and line. The four rows without evidence cannot be written in v0.1.0:

- `calls`, `derived-from` and `same-as` are reserved or derived relations with no authoring syntax.
- `has-part` in a manifest is listed in ADVANCED.md but rejected by the manifest schema (GM110, ADOPTION-LOG L18). It is shown in ontologies instead.

Two rows are covered only by a workaround. `policy.coverage-fail-under: current` makes every command fail when written in `glossmark.yaml` (L32), so the ratchet comes from the CI flag. `dangling` cannot coexist with a clean `check` (GM215), so it is shown by `showcase/claims-events/demo/dangling.sh`.

### Top ten findings, by impact

1. [F-XCUT-1](lab/cross-cutting-concerns/FINDINGS.md#f-xcut-1-deleting-a-guard-decorator-is-invisible-to-every-command): deleting `@requires_role(...)` from a high-criticality handler changes nothing in any command. Design gap.
2. [F-SPLIT-1](lab/monolith-decomposition/FINDINGS.md#f-split-1-graphjsonl-records-imported-ontologies-with-absolute-paths): importer graphs record absolute paths, so a committed graph is never current in another checkout (also FF22). Bug.
3. [F-ADOPT-8](lab/FINDINGS-ADOPTION.md#f-adopt-8-accepting-a-scopefile-proposal-makes-it-stale-and-it-cannot-be-re-confirmed): accepting a `scope=file` proposal makes it stale at once, and nothing can re-confirm it. Hit in every showcase example. Bug.
4. [F-VER-1](lab/version-evolution/FINDINGS.md#f-ver-1-a-forgotten-bump-passes-the-owners-gate-and-breaks-every-importer) with [F-VER-2](lab/version-evolution/FINDINGS.md#f-ver-2-gloss-lock-records-a-version-the-range-forbids-and-the-lock-does-not-pin): a forgotten bump passes the owner's gate and fails every importer, and the fix the error suggests (`gloss lock`) records versions the range forbids. Design gap plus bug.
5. [F-SPLIT-3](lab/monolith-decomposition/FINDINGS.md#f-split-3-an-imported-implementation-namespace-is-typed-core-unless-the-import-says-tier-which-is-undocumented) with [F-VER-4](lab/version-evolution/FINDINGS.md#f-ver-4-the-published-only-rule-for-imported-implementation-concepts-is-not-enforced) and FF8: the published seam between repositories is not enforced unless an undocumented `tier:` key is set. Bug.
6. [F-DEEP-1](lab/deep-hierarchies/FINDINGS.md#f-deep-1-a-declared-part-covers-its-whole-so-a-leaf-declaration-admits-the-entire-process): a manifest declaring a part accepts code that implements the whole, with no violation and no gap. Bug.
7. [F-DEEP-2](lab/deep-hierarchies/FINDINGS.md#f-deep-2-kind-is-not-inherited-through-is-a-so-represents-on-a-subtype-gives-a-false-gap): `kind` is not inherited through `is-a`, so `represents` on a subtype gives a false gap that fails drift by default. Bug.
8. [F-CAL-1](lab/confidence-calibration/FINDINGS.md): `suggest` is far from its own auto-accept gate (pooled SOFT 15.7% at 85.2% precision), and `conf` is a lexical score that cannot be calibrated (F-CAL-5). Design gap.
9. [F-ADOPT-3](lab/FINDINGS-ADOPTION.md#f-adopt-3-doctor-reports-an-unrelated-gloss-on-path-as-healthy): `doctor` reports an unrelated `gloss` on `PATH` as healthy, while the hook and MCP entry silently call it. Bug.
10. [F-SPLIT-2](lab/monolith-decomposition/FINDINGS.md#f-split-2-two-live-implementations-of-one-capability-are-silent): two live implementations of one capability during a migration produce no finding anywhere. Design gap.

### v0.1.0 bugs, as distinct from design gaps

Each has a repro in the linked file.

- **Adoption:** F-ADOPT-3 (doctor PATH), F-ADOPT-5 (suggest text truncates at 80), F-ADOPT-8 (scope=file stale on accept), F-ADOPT-11 (unknown `--fail-on` kinds ignored), F-ADOPT-12 (Action comment not keyed by root).
- **Library-legacy rows:** L3 (`import` flags after the file are not parsed), L6 (enum import overwrites a glossary concept on every run), L21 (`tests` stored as its own predicate), L22 (`scope=range` JSON Pointers never resolved), L25 (waiver `expires:` not validated), L28 (status export says implemented from `documents` links), L32 (`coverage-fail-under: current` rejected in the policy).
- **Freight-federation rows:** FF15 (`published-as` emitted twice in JSON-LD), FF17 (diff prints an absolute path for an imported file), FF22 (= F-SPLIT-1).
- **Lab:** F-SPLIT-1, F-SPLIT-3, F-SPLIT-6 (an unknown manifest key discards the whole boundary), F-SPLIT-11 (context-map arrows contradict the header), F-SPLIT-12 (diff base file coverage); F-VER-2, F-VER-3, F-VER-4, F-VER-10 (lock output order); F-DEEP-1, F-DEEP-2, F-DEEP-3 (GM320 half), F-DEEP-4 (sibling parent boundary); F-XCUT-4 (GM131 misses stacked markers), F-XCUT-9 (`impact --base` zero base), F-XCUT-10 (GM200 per target); F-CAL-6 (shared marker id), F-CAL-7 (`--min-score`); F-POOR-4 (same-named methods collapse), F-POOR-5 (rejected proposals re-proposed); F-SURF-1 (presented file criticality), F-SURF-6 (surface credited with engine tests).

Everything else in the findings files is a design gap or a documentation gap.

### Duplicates to file once

F-SPLIT-1 and FF22; F-SPLIT-3, F-VER-4 and FF8; F-SPLIT-9 and F-VER-9; F-SPLIT-4 and the owner side of F-VER-1; F-SPLIT-10, L25 and L26 (waivers); F-VER-11, F-SPLIT-11's path half and FF16 (landscape paths); C9, F-CAL-2 and FF5 (`suggest` reads `derived` literally).

### Not done

- Nothing was pushed, so neither workflow has run on GitHub. Both were checked locally only (`scripts/ci-local.sh`, YAML parse).
- The sibling repositories' own `ci.yml` files build their code but do not run GlossMark; the root `showcase.yml` does that for them.
- Lab agents could not write `FINDINGS.md` themselves; the coordinator saved their text unchanged apart from cross-links between duplicate findings.
