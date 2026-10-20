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
