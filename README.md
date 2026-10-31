# GlossMark examples

Realistic, multi-language codebases adopted with [GlossMark](https://github.com/McKalvan/GlossMark) **v0.1.0**, plus a lab that probes its modelling and turns every rough edge into an issue-ready finding. The repository now tracks GlossMark main: every script and workflow runs the commit pinned in [GLOSS_REF](GLOSS_REF), currently GlossMark main at the merge of PR #255 (see [Tracking GlossMark](#tracking-glossmark)).

The small examples and the conformance corpus stay in the main repository, where they gate its CI. Everything here is new material. The code is realistic but inert: syntactically valid, never built, no dependencies installed.

| Directory | What |
| --- | --- |
| [`showcase/`](showcase) | Five stable examples, each a different shape. Gated by [showcase.yml](.github/workflows/showcase.yml) on every push and pull request |
| [`lab/`](lab) | Seven experiments that may break, run weekly by [lab.yml](.github/workflows/lab.yml). Each ends in a `FINDINGS.md` written as GlossMark issues |
| [`scripts/`](scripts) | Install the GlossMark pinned in `GLOSS_REF`, run the showcase checks locally, verify the feature matrix |
| [PLAN.md](PLAN.md) | The plan, the progress log and the final report |
| [CONTRIBUTING.md](CONTRIBUTING.md) | What is stable (showcase) and what is not (lab) |

## Showcase

| Example | Shape | Stack | Shows most clearly |
| --- | --- | --- | --- |
| [clinic-booking](showcase/clinic-booking) | Monorepo web product | Next.js, Go, Python, Postgres, Terraform, Kubernetes, Actions | pages and shells, infrastructure and deploy links, published values, criticality with a floor, curated views, `realizes: inherit` |
| [freight-federation](showcase/freight-federation) | Three repositories sharing one core | Java/Spring, TypeScript/Node, Rust | imports pinned by `gloss lock`, `publish`, `landscape`, cross-repo extension of a shared core, a HARD gate on a published concept |
| [claims-events](showcase/claims-events) | Event-driven system | Kafka, Avro, AsyncAPI, Kotlin, Python, Go | `produces`/`consumes`/`publishes`/`subscribes`, event taxonomy, custom relations, violation, gap and value-drift |
| [kitchen-agents](showcase/kitchen-agents) | Agent-heavy repository | FastAPI, TypeScript, AGENTS.md, skills, three subagents | `instructs`, `may-modify` remits, every review state, the hook, `gloss agents`, `gloss context`, the MCP server |
| [library-legacy](showcase/library-legacy) | Brownfield adoption | Java servlets, Perl, shell, Ruby, SQL, protobuf, Terraform | the importers, deprecation, waivers, every scope including JSON sidecars, the coverage ratchet |

Each example's README tells the system's story, lists its two ontology tiers and boundaries, and has a table of every drift finding it produces (derived from code, declared, result). The findings are intentional. CI checks each workspace against golden files:

1. `gloss check` exits 0 and its output matches `expected-check.txt`.
2. `gloss drift --fail-on <kinds>` passes for the kinds registered in [showcase/workspaces.tsv](showcase/workspaces.tsv).
3. The full drift output matches `expected-drift.txt`.
4. A rebuild changes neither `graph.jsonl` nor `ledger.jsonl`.
5. Multi-repo examples also match `expected-landscape.txt` ([showcase/landscapes.tsv](showcase/landscapes.tsv)).

Workspaces with no intentional violation, value-drift, dangling or overdue finding also run the GitHub Action, pinned to the same commit as `GLOSS_REF` (`mckalvan/glossmark@<commit>`); the others run the pinned binary directly, because the Action fails on those kinds by default. `freight-federation/dispatch` and `tracking` left the Action while their event payload types derived `holds` violations, and rejoined it when GlossMark #172 was fixed. Behaviour that needs two states (a gate on a change, a stale link, a removed proposal) is shown by scripts in each example's `demo/` directory, which work on a temporary git copy.

**Multi-repo note.** `freight-federation` keeps its three repositories as sibling directories wired with relative import paths and pinned with `gloss lock`. The pinned GlossMark, like v0.1.0, accepts local import paths only; once GlossMark's remote import fetcher ships, the siblings become separate repositories. `gloss lock` also vendors each locked import under `.glossmark/imports/` and keeps resolving that copy until `gloss lock --update`; dispatch and tracking commit theirs. Without the vendored copy, `gloss diff --base` read the base commit as having no imports and listed every imported concept as added.

## Lab

| Experiment | Question |
| --- | --- |
| [cross-cutting-concerns](lab/cross-cutting-concerns) | How to model auth, audit and rate limiting that touch every handler |
| [deep-hierarchies](lab/deep-hierarchies) | Do `is-a` and `part-of` chains several levels deep roll up and lint as expected |
| [monolith-decomposition](lab/monolith-decomposition) | Can the ontology follow a monolith as it is split into services |
| [ambiguous-surfaces](lab/ambiguous-surfaces) | `presents`, `hosts` or `implements` for a BFF, server pages, a CLI, GraphQL, an admin value editor and a PDF |
| [concept-poor-legacy](lab/concept-poor-legacy) | What `suggest` can do for code whose names carry no domain words |
| [confidence-calibration](lab/confidence-calibration) | Does `suggest`'s `conf=` predict which proposals a reviewer keeps |
| [version-evolution](lab/version-evolution) | What happens to importers when a shared core changes version |

Friction met while adopting the showcase examples is in [lab/ADOPTION-LOG.md](lab/ADOPTION-LOG.md), distilled into issues in [lab/FINDINGS-ADOPTION.md](lab/FINDINGS-ADOPTION.md). The lab was written against v0.1.0 and is left as it was. confidence-calibration's labelled dataset was produced with v0.1.0 `gloss suggest` and needs re-labelling against the new suggester: its `run.sh` now reports `DIFFERS` for the committed suggest output.

## Feature matrix

Every relation, scope, marker key, drift finding, gate, concept kind, review state and CLI command of GlossMark v0.1.0 (from its `docs/ADVANCED.md`, `docs/FILE-FORMATS.md` and `README.md`), and the file in each example that shows it. The rows are v0.1.0's; finding kinds added since (`overdue`, `out-of-range`, `deprecated-use`, `overlap`) have no row yet, although library-legacy's drift now shows `deprecated-use`. `python3 scripts/feature-matrix.py --check` verifies that every cited file and line exists; `--write` regenerates this table from [showcase/feature-matrix.tsv](showcase/feature-matrix.tsv). Rows marked uncoverable cannot be written in v0.1.0, and still cannot with the pinned GlossMark (`has-part` in a manifest is still GM110).

<!-- feature-matrix:begin -->
**Inline relations (@gloss markers)**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| implements | [✓](showcase/clinic-booking/services/booking-api/internal/booking/service.go#L58) |  |  |  |  |
| represents | [✓](showcase/clinic-booking/services/booking-api/internal/models/patient.go#L10) |  | [✓](showcase/claims-events/schemas/MotorClaimFiled.avsc.gloss#L2) |  | [✓](showcase/library-legacy/db/schema/004_loans.sql#L3) |
| presents | [✓](showcase/clinic-booking/apps/web/components/AppointmentCard.tsx#L5) |  |  |  |  |
| hosts | [✓](showcase/clinic-booking/apps/web/components/NavBar.tsx#L3) |  |  |  |  |
| verifies | [✓](showcase/clinic-booking/services/booking-api/internal/booking/cancellation_test.go#L29) | [✓](showcase/freight-federation/dispatch/test/contract/shipmentBooked.contract.test.ts#L1) |  | [✓](showcase/kitchen-agents/api/tests/test_allergen_guard.py#L26) |  |
| tests (alias of verifies; GM240) |  |  |  |  | [✓](showcase/library-legacy/src/test/java/gov/riverbend/circ/service/FineCalculatorTest.java#L21) |
| documents | [✓](showcase/clinic-booking/docs/architecture.md#L5) | [✓](showcase/freight-federation/shipment-core/docs/event-catalogue.md#L13) |  |  |  |
| instructs |  |  |  | [✓](showcase/kitchen-agents/.claude/agents/menu-curator.md#L7) |  |
| publishes-value | [✓](showcase/clinic-booking/services/reminders/reminders/settings.py#L5) |  |  |  |  |
| may-modify |  |  |  | [✓](showcase/kitchen-agents/.claude/agents/menu-curator.md#L8) |  |
| provisions | [✓](showcase/clinic-booking/infra/terraform/database.tf#L11) |  | [✓](showcase/claims-events/platform/kafka/cluster.yaml#L2) |  |  |
| configures | [✓](showcase/clinic-booking/deploy/k8s/booking-api/configmap.yaml#L1) |  |  |  |  |
| deploys | [✓](showcase/clinic-booking/deploy/k8s/booking-api/deployment.yaml#L1) |  |  |  |  |
| produces |  |  | [✓](showcase/claims-events/services/claim-intake/src/main/kotlin/com/tidewater/claims/intake/api/ClaimRoutes.kt#L55) |  |  |
| consumes | [✓](showcase/clinic-booking/services/reminders/reminders/models.py#L13) |  | [✓](showcase/claims-events/services/claim-intake/src/main/kotlin/com/tidewater/claims/intake/policy/PolicyClient.kt#L28) |  |  |
| publishes |  | [✓](showcase/freight-federation/dispatch/src/events/publisher.ts#L52) | [✓](showcase/claims-events/services/claim-intake/src/main/kotlin/com/tidewater/claims/intake/events/ClaimEventPublisher.kt#L35) |  |  |
| subscribes |  | [✓](showcase/freight-federation/tracking/src/consumers/picked_up.rs#L15) | [✓](showcase/claims-events/services/fraud-screening/src/main/kotlin/com/tidewater/claims/fraud/ScreeningTopology.kt#L26) |  |  |

**Ontology relations (*.gloss.yaml)**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| presents | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L83) |  |  |  |  |
| hosts | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L18) |  |  |  |  |
| produces | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L29) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L112) |  |  |
| consumes | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L28) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L97) |  |  |
| publishes |  |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L99) |  |  |
| subscribes |  |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L110) |  |  |
| realizes | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L24) |  |  |  |  |
| is-a |  | [✓](showcase/freight-federation/dispatch/ontology/dsp.gloss.yaml#L23) | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L61) |  |  |
| part-of | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L53) | [✓](showcase/freight-federation/tracking/ontology/trk.gloss.yaml#L16) |  |  |  |
| has-part |  | [✓](showcase/freight-federation/shipment-core/ontology/frt.gloss.yaml#L10) |  |  | [✓](showcase/library-legacy/ontology/circ.gloss.yaml#L19) |
| published-as (published: { as: ... }) | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L37) | [✓](showcase/freight-federation/shipment-core/ontology/shc.gloss.yaml#L23) |  |  |  |
| constrains | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L53) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L140) |  |  |
| reverses | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L35) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L104) |  |  |
| attaches-to |  |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L33) |  |  |
| custom relation (declared under relations:) |  |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L114) |  |  |

**Manifest relations (.gloss.yaml)**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| presents | [✓](showcase/clinic-booking/apps/web/.gloss.yaml#L8) |  |  |  |  |
| hosts | [✓](showcase/clinic-booking/apps/web/.gloss.yaml#L9) |  |  |  |  |
| produces |  |  | [✓](showcase/claims-events/.gloss.yaml#L11) |  |  |
| consumes |  |  | [✓](showcase/claims-events/.gloss.yaml#L12) |  |  |
| publishes |  |  | [✓](showcase/claims-events/.gloss.yaml#L9) |  |  |
| subscribes |  |  | [✓](showcase/claims-events/services/payout-notifier/.gloss.yaml#L8) |  |  |
| realizes | [✓](showcase/clinic-booking/services/booking-api/.gloss.yaml#L6) |  |  |  |  |
| holds | [✓](showcase/clinic-booking/db/.gloss.yaml#L7) |  |  |  |  |
| part-of | [✓](showcase/clinic-booking/services/booking-api/.gloss.yaml#L5) |  |  |  |  |
| has-part (uncoverable: ADVANCED.md lists it, but v0.1.0 rejects it in a manifest (GM110, ADOPTION-LOG L18)) |  |  |  |  |  |

**Derived and reserved relations**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| depends-on (derived; the landscape context map) |  | [✓](showcase/freight-federation/expected-landscape.txt#L3) |  |  |  |
| calls (uncoverable: reserved for the SCIP join, not in v0.1.0) |  |  |  |  |  |
| derived-from (uncoverable: reserved, not written by v0.1.0) |  |  |  |  |  |
| same-as (uncoverable: reserved for SSSOM mappings, not in v0.1.0) |  |  |  |  |  |

**Scopes**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| (none) (next declaration) | [✓](showcase/clinic-booking/services/booking-api/internal/booking/service.go#L58) |  |  |  |  |
| symbol | [✓](showcase/clinic-booking/services/booking-api/internal/outbox/relay.go#L12) |  |  |  | [✓](showcase/library-legacy/src/main/java/gov/riverbend/circ/service/CirculationService.java#L119) |
| file | [✓](showcase/clinic-booking/deploy/k8s/booking-api/configmap.yaml#L1) |  |  | [✓](showcase/kitchen-agents/CLAUDE.md#L1) | [✓](showcase/library-legacy/batch/overdue_notices.pl#L2) |
| block |  |  | [✓](showcase/claims-events/contracts/asyncapi.yaml#L24) | [✓](showcase/kitchen-agents/kds/tests/ticketStore.test.ts#L9) | [✓](showcase/library-legacy/config/circulation.yaml#L3) |
| line | [✓](showcase/clinic-booking/services/reminders/reminders/settings.py#L5) |  | [✓](showcase/claims-events/services/claim-intake/src/main/kotlin/com/tidewater/claims/intake/domain/FilingWindow.kt#L8) |  | [✓](showcase/library-legacy/src/main/java/gov/riverbend/circ/model/LoanStatus.java#L10) |
| range (JSON Pointer sidecar) |  |  | [✓](showcase/claims-events/schemas/MotorClaimFiled.avsc.gloss#L2) |  | [✓](showcase/library-legacy/config/loan-rules.json.gloss#L1) |

**Marker keys**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| conf | [✓](showcase/clinic-booking/services/booking-api/internal/booking/availability.go#L17) |  |  | [✓](showcase/kitchen-agents/api/ordering/routers/menu.py#L18) |  |
| note |  |  | [✓](showcase/claims-events/schemas/MotorClaimFiled.avsc.gloss#L2) | [✓](showcase/kitchen-agents/api/ordering/routers/menu.py#L18) |  |
| id |  |  |  | [✓](showcase/kitchen-agents/api/ordering/routers/menu.py#L18) |  |
| scope | [✓](showcase/clinic-booking/services/booking-api/internal/outbox/relay.go#L12) |  |  |  | [✓](showcase/library-legacy/config/loan-rules.json.gloss#L1) |

**Drift findings**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| violation |  |  | [✓](showcase/claims-events/expected-drift.txt#L4) |  |  |
| gap |  |  | [✓](showcase/claims-events/expected-drift.txt#L10) |  | [✓](showcase/library-legacy/expected-drift.txt#L4) |
| value-drift | [✓](showcase/clinic-booking/demo/gates.sh#L35) |  | [✓](showcase/claims-events/expected-drift.txt#L7) |  |  |
| dangling |  |  | [✓](showcase/claims-events/demo/dangling.sh#L3) |  |  |
| rogue |  |  |  | [✓](showcase/kitchen-agents/expected-drift.txt#L4) |  |
| orphan | [✓](showcase/clinic-booking/expected-drift.txt#L4) |  | [✓](showcase/claims-events/expected-drift.txt#L13) |  | [✓](showcase/library-legacy/expected-drift.txt#L13) |
| untested | [✓](showcase/clinic-booking/expected-drift.txt#L10) |  |  | [✓](showcase/kitchen-agents/expected-drift.txt#L13) | [✓](showcase/library-legacy/expected-drift.txt#L22) |
| presented-only | [✓](showcase/clinic-booking/expected-drift.txt#L7) |  |  |  |  |
| stale |  |  |  | [✓](showcase/kitchen-agents/expected-drift.txt#L10) |  |
| proposed |  |  |  | [✓](showcase/kitchen-agents/expected-drift.txt#L7) | [✓](showcase/library-legacy/expected-drift.txt#L7) |

**Gates**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| AUTO | [✓](showcase/clinic-booking/demo/gates.sh#L22) |  |  | [✓](showcase/kitchen-agents/README.md#L171) |  |
| SOFT | [✓](showcase/clinic-booking/demo/gates.sh#L28) |  |  | [✓](showcase/kitchen-agents/demo/remit.sh#L32) |  |
| HARD | [✓](showcase/clinic-booking/demo/gates.sh#L32) | [✓](showcase/freight-federation/README.md#L182) |  | [✓](showcase/kitchen-agents/demo/remit.sh#L3) |  |

**Concept kinds**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| entity | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L9) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L10) |  |  |
| process | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L27) |  |  |  |  |
| capability | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L38) |  |  |  |  |
| event |  | [✓](showcase/freight-federation/shipment-core/ontology/frt.gloss.yaml#L53) | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L46) |  |  |
| measure | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L49) |  |  |  |  |
| constraint | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L52) |  |  |  |  |
| resource | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L68) |  |  |  |  |
| system-type | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L9) |  |  |  |  |

**Review states**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| proposed |  |  |  | [✓](showcase/kitchen-agents/.glossmark/ledger.jsonl#L2) |  |
| accepted | [✓](showcase/clinic-booking/.glossmark/ledger.jsonl#L2) |  |  | [✓](showcase/kitchen-agents/.glossmark/ledger.jsonl#L5) |  |
| rejected |  |  |  | [✓](showcase/kitchen-agents/.glossmark/ledger.jsonl#L56) |  |
| stale |  |  |  | [✓](showcase/kitchen-agents/.glossmark/ledger.jsonl#L22) |  |
| removed |  |  |  | [✓](showcase/kitchen-agents/demo/review.sh#L6) |  |

**CLI commands**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| init | [✓](showcase/clinic-booking/README.md#L118) |  |  |  |  |
| suggest | [✓](showcase/clinic-booking/README.md#L118) |  |  |  |  |
| import |  |  |  |  | [✓](showcase/library-legacy/demo/reimport.sh#L22) |
| criticality | [✓](showcase/clinic-booking/demo/tour.sh#L14) |  |  |  |  |
| build | [✓](showcase/clinic-booking/demo/gates.sh#L38) |  |  |  |  |
| check | [✓](showcase/clinic-booking/expected-check.txt#L1) |  |  |  |  |
| drift | [✓](showcase/clinic-booking/expected-drift.txt#L1) |  |  |  |  |
| diff | [✓](showcase/clinic-booking/demo/gates.sh#L4) | [✓](showcase/freight-federation/demo/published-change.sh) |  |  |  |
| impact | [✓](showcase/clinic-booking/demo/tour.sh#L15) |  |  |  |  |
| coverage | [✓](showcase/clinic-booking/demo/tour.sh#L13) |  |  |  | [✓](showcase/library-legacy/demo/ratchet.sh#L2) |
| accept | [✓](showcase/clinic-booking/README.md#L118) |  |  | [✓](showcase/kitchen-agents/demo/review.sh#L31) |  |
| reject |  |  |  | [✓](showcase/kitchen-agents/demo/review.sh#L5) |  |
| status |  |  |  | [✓](showcase/kitchen-agents/demo/remit.sh#L47) |  |
| propose |  |  |  | [✓](showcase/kitchen-agents/demo/review.sh#L5) |  |
| context |  |  |  | [✓](showcase/kitchen-agents/demo/remit.sh#L50) |  |
| hook |  |  |  | [✓](showcase/kitchen-agents/.claude/settings.json#L7) |  |
| doctor | [✓](showcase/clinic-booking/demo/tour.sh#L23) |  |  |  | [✓](showcase/library-legacy/demo/tour.sh#L21) |
| lock |  | [✓](showcase/freight-federation/dispatch/glossmark.lock) |  |  |  |
| view | [✓](showcase/clinic-booking/demo/tour.sh#L16) |  |  |  |  |
| export | [✓](showcase/clinic-booking/demo/tour.sh#L17) |  |  | [✓](showcase/kitchen-agents/demo/review.sh#L7) | [✓](showcase/library-legacy/demo/tour.sh#L17) |
| publish |  | [✓](showcase/freight-federation/demo/publish.sh#L11) |  |  |  |
| landscape |  | [✓](showcase/freight-federation/expected-landscape.txt) |  |  |  |
| agents |  |  |  | [✓](showcase/kitchen-agents/AGENTS.md#L30) |  |
| mcp |  |  |  | [✓](showcase/kitchen-agents/demo/mcp.py#L25) |  |
| version | [✓](showcase/clinic-booking/demo/tour.sh#L11) |  |  |  |  |

**File-format features**

| Row | clinic-booking | freight-federation | claims-events | kitchen-agents | library-legacy |
| --- | :-: | :-: | :-: | :-: | :-: |
| grammar: 1 | [✓](showcase/clinic-booking/glossmark.yaml#L2) |  |  |  |  |
| imports with a version range |  | [✓](showcase/freight-federation/dispatch/glossmark.yaml#L9) |  |  |  |
| glossmark.lock |  | [✓](showcase/freight-federation/tracking/glossmark.lock) |  |  |  |
| policy.soft-conf-threshold | [✓](showcase/clinic-booking/glossmark.yaml#L8) |  |  | [✓](showcase/kitchen-agents/glossmark.yaml#L13) |  |
| policy.waivers (with an expiry) |  |  |  |  | [✓](showcase/library-legacy/glossmark.yaml#L9) |
| policy.coverage-fail-under: current (ratchet) |  |  |  |  | [✓](showcase/library-legacy/README.md#L325) |
| value-from | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L39) |  | [✓](showcase/claims-events/ontology/tide.gloss.yaml#L55) |  |  |
| deprecated + replaced-by |  |  |  |  | [✓](showcase/library-legacy/ontology/lib.gloss.yaml#L132) |
| internal | [✓](showcase/clinic-booking/ontology/lark.gloss.yaml#L3) |  |  |  |  |
| aliases | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L14) |  |  |  |  |
| criticality on a concept | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L17) |  |  | [✓](showcase/kitchen-agents/ontology/dine.gloss.yaml#L62) |  |
| criticality on a boundary | [✓](showcase/clinic-booking/services/booking-api/.gloss.yaml#L10) |  |  |  |  |
| criticality-floor | [✓](showcase/clinic-booking/db/.gloss.yaml#L11) |  |  |  |  |
| realizes: inherit | [✓](showcase/clinic-booking/.gloss.yaml#L6) |  |  |  |  |
| allowed: [derived, ...] | [✓](showcase/clinic-booking/services/reminders/.gloss.yaml#L10) |  |  |  |  |
| allowed (written list) |  |  |  | [✓](showcase/kitchen-agents/kds/.gloss.yaml#L12) |  |
| lift: range-lcs | [✓](showcase/clinic-booking/ontology/clinic.gloss.yaml#L62) |  | [✓](showcase/claims-events/ontology/claim.gloss.yaml#L155) |  |  |
| views.yaml curated view | [✓](showcase/clinic-booking/ontology/views.yaml#L16) |  |  |  |  |
<!-- feature-matrix:end -->

## Tracking GlossMark

[GLOSS_REF](GLOSS_REF) names the GlossMark this repository runs: a release tag (`vX.Y.Z`) or a full commit SHA on GlossMark main. It is currently `0be26e3d2682528175f72aa3de6820722d5b3029`, GlossMark main at the merge of PR #255. `scripts/install-gloss.sh` reads it: a tag downloads the release binary, a commit is built with `go install` (Go 1.24). The binary of a commit reports `gloss 0.0.0-dev`; `.tools/bin/gloss.ref` records which ref it was built from.

To bump it:

1. Edit `GLOSS_REF` and the `uses: mckalvan/glossmark@<sha>` line (and its `version:`) in [.github/workflows/showcase.yml](.github/workflows/showcase.yml) together. `uses:` takes no expression, and the matrix job fails when the two differ.
2. Run `UPDATE=1 scripts/ci-local.sh`. It installs the new binary and rewrites every `expected-*.txt`, but skips the graph check, so also run `gloss build` in each workspace and commit what changes under `.glossmark/`.
3. Review the golden diffs. Each changed line is a change in what GlossMark reports about the same code; decide whether it is the documented drift or something to fix in the example or report upstream.
4. Update each example README's drift table and quoted output from the new golden files, then run `scripts/ci-local.sh` and `python3 scripts/feature-matrix.py --check`.

Bump it in the same commit that regenerates the golden files.

## Run it

```sh
sh scripts/install-gloss.sh          # the GlossMark in GLOSS_REF into .tools/bin (a release sha256-verified, a commit built with go install)
export GLOSS=$PWD/.tools/bin/gloss
$GLOSS version
scripts/ci-local.sh                  # every showcase check, exactly as CI runs them
python3 scripts/feature-matrix.py --check
cd showcase/clinic-booking && $GLOSS drift && demo/tour.sh
lab/version-evolution/run.sh         # any lab experiment's key outputs
```

Use `$GLOSS`, not a bare `gloss`, if another program of that name is on your `PATH`.
