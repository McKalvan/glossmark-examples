# Kestrel Freight: three repositories, one core

**Shape:** three sibling repositories that share one core tier. **Shows:** the published seam (`published: { as: }`) between an implementation tier and the business view and across repositories, importing a core and an implementation namespace with semver ranges, `gloss lock` and `glossmark.lock`, extension under the own-subject rule (`is-a` and `part-of` onto imported concepts), `has-part`, events with `publishes`/`subscribes` inline, in the ontology and in manifests, `gloss landscape` with its context map and cross-repo drift, a HARD gate on a published change and on a MAJOR bump, and `gloss publish`.

Kestrel Freight moves parcels by road. A shipper books a shipment; the shipment service prints its labels, picks a carrier and promises a two-hour delivery window. Dispatch plans which driver collects it and when. Once it is collected, tracking follows the driver's GPS pings and depot scans until the driver arrives at the delivery address, and records the proof of delivery. Every delivery counts toward the on-time rate, the measure operations watch.

| Repository | What | Stack | Owns | Imports |
| --- | --- | --- | --- | --- |
| [shipment-core](shipment-core) | Booking, labels, carrier assignment, the delivery-window promise, the on-time rate, the ShipmentBooked outbox | Java 21, Spring Boot 3, JPA, Flyway, Kafka, JUnit 5 | `frt:` (core), `shc:` (implementation) | |
| [dispatch](dispatch) | Pickup planning: driver matching, route optimisation, express pickups, pickup confirmation | TypeScript, Node 20, Fastify, kafkajs, Prisma, vitest | `dsp:` | `frt: ^1.4`, `shc: ~1.1.0` |
| [tracking](tracking) | GPS pings, scans, geofence arrival, proof of delivery, the tracking API | Rust, axum, sqlx, rdkafka, cargo tests | `trk:` | `frt: ^1.3`, `shc: ^1.1` |

The three directories are **separate repositories in all but location**: each has its own `glossmark.yaml`, ledger, graph and CI workflow, and the importers reach the core through a relative path (`source: ../shipment-core/ontology/frt.gloss.yaml`). GlossMark v0.1.0 accepts local paths only; `git+` and `https://` sources are parsed and rejected. Once GlossMark's remote import fetcher ships, the three directories become three repositories and the `source:` lines become git references.

One v0.1.0 bug shows in the committed files: `dispatch/.glossmark/graph.jsonl` and `tracking/.glossmark/graph.jsonl` record the imported ontology files by absolute path, the path of the checkout that built them, although `source:` is relative ([F-SPLIT-1](../../lab/monolith-decomposition/FINDINGS.md#f-split-1-graphjsonl-records-imported-ontologies-with-absolute-paths), FF22). A rebuild in another checkout rewrites those lines, so `scripts/check-workspace.sh` replaces the checkout prefix before it compares graphs.

The code is realistic but inert: it is never built here.

```
shipment.booked.v1      shipment-core ──────▶ dispatch
shipment.picked-up.v1   dispatch      ──────▶ tracking, shipment-core
shipment.delivered.v1   tracking      ──────▶ shipment-core
dispatch.routes.v1      dispatch      ──────▶ tracking
```

## The tiers, across three repositories

**Core, `frt:`** ([shipment-core/ontology/frt.gloss.yaml](shipment-core/ontology/frt.gloss.yaml), version 1.4.0) is what a freight planner recognises: `Shipment` (which `has-part` `Parcel`), `Consignment` (which `has-part` `Shipment`), `Carrier`, `ShippingLabel`, `Route`, `Driver` (entities); `Booking`, `Labelling`, `CarrierAssignment`, `Dispatching`, `Pickup`, `Tracking`, `Delivery` (processes); `ShipmentVisibility` (a capability); `ShipmentBooked`, `ShipmentPickedUp`, `ShipmentDelivered` (**events**, each published by the process that causes it); `DeliveryWindow` and `LabelFormat` (constraints); `OnTimeDeliveryRate` (a measure). shipment-core owns it because the shipment is the contract; the other two import it.

**Implementation, one namespace per repository.** `shc:` (shipment-core), `dsp:` (dispatch) and `trk:` (tracking) name the handlers, emitters, consumers and stores of each service, each realizing a core concept or marked `internal`.

### The published seam

Four `shc:` concepts are **published**: each carries `published: { as: <core concept> }`, and they are the only `shc:` concepts the other two repositories may reference:

| Concept | Published as | Value | Bound to | Referenced from |
| --- | --- | --- | --- | --- |
| `shc:ShipmentBookedEmitter` | `frt:ShipmentBooked` | | the outbox relay | dispatch's consumer-driven contract test ([shipmentBooked.contract.test.ts](dispatch/test/contract/shipmentBooked.contract.test.ts)) |
| `shc:DeliveryWindowPolicy` | `frt:DeliveryWindow` | `2h` | `value-from: WINDOW_LENGTH` in [DeliveryWindowPolicy.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/booking/DeliveryWindowPolicy.java) | tracking's lateness test ([tests/window.rs](tracking/tests/window.rs)) and its docs |
| `shc:LabelSpec` | `frt:LabelFormat` | `ZPL II, 4x6 in, 203 dpi` | `value-from: FORMAT` in [LabelSpec.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/label/LabelSpec.java) | |
| `shc:OnTimeRateCalculator` | `frt:OnTimeDeliveryRate` | `95%` | `value-from: TARGET` in [OnTimeRateCalculator.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/metrics/OnTimeRateCalculator.java) | |

`shc.gloss.yaml` says `tier: implementation` at the top. Without that line, an importer does not know `shc:` is an implementation namespace, and GM230 (an unpublished concept referenced across repositories) never fires; see [the seam demo](#the-published-seam-holds) below.

### Extension under the own-subject rule

A repository may only add statements whose subject is in a namespace it owns. The importers extend the core that way:

| Statement | Where | Meaning |
| --- | --- | --- |
| `dsp:ExpressPickup is-a frt:Pickup` | [dispatch/ontology/dsp.gloss.yaml](dispatch/ontology/dsp.gloss.yaml) | a same-day pickup is a pickup; it inherits `realizes frt:Pickup` (`gloss landscape --all` lists `frt:Pickup` in `dispatch:planner`'s derived `realizes`) |
| `trk:GeofenceArrival part-of frt:Delivery` | [tracking/ontology/trk.gloss.yaml](tracking/ontology/trk.gloss.yaml) | arrival detection is part of delivery; code that implements it realizes `frt:Delivery` |
| `dsp:DriverMatcher part-of dsp:PickupPlanner` | dispatch | a part within the repository's own tier |

`gloss drift` in dispatch turns the `is-a` into a decision request for the core's owner: `dsp:ExpressPickup extends imported frt:Pickup; if the core should have it, propose frt:ExpressPickup upstream and deprecate dsp:ExpressPickup with replaced-by`.

## Boundaries

| Manifest | Boundary | Declares |
| --- | --- | --- |
| [shipment-core/.gloss.yaml](shipment-core/.gloss.yaml) | `fleet:freight-platform` (system) | `publishes` all three events: the platform's event catalogue, kept next to the core |
| [shipment-core/service/.gloss.yaml](shipment-core/service/.gloss.yaml) | `shipcore:shipment-service` | `part-of` the platform; `realizes` eight `shc:` concepts; `holds` five entities; `produces` Shipment and ShippingLabel; `publishes` ShipmentBooked; `subscribes` ShipmentPickedUp and ShipmentDelivered |
| [dispatch/.gloss.yaml](dispatch/.gloss.yaml) | `dispatch:planner` | `part-of` the platform; `consumes` Shipment, `produces` Route, `subscribes` ShipmentBooked, `publishes` ShipmentPickedUp; `generated:` Prisma migrations; `allowed: [derived, shc:ShipmentBookedEmitter]` for the contract test |
| [tracking/.gloss.yaml](tracking/.gloss.yaml) | `tracking:tracker` | `part-of` the platform; `consumes` Route, `subscribes` ShipmentPickedUp, `publishes` ShipmentDelivered; `allowed: [derived, shc:DeliveryWindowPolicy]` for the lateness test |

`fleet:` is a boundary prefix all three `glossmark.yaml` files declare, so `part-of: fleet:freight-platform` in dispatch and tracking names the boundary that shipment-core defines. Each repository has its own boundary prefix under its own `repo-iri`.

Events are linked three ways. shipment-core declares them on implementation concepts (`shc:ShipmentBookedEmitter publishes frt:ShipmentBooked`, `shc:StatusProjector subscribes` the other two), so the marker on the outbox relay is a plain `implements`. dispatch and tracking mark the code that touches the topic inline: `// @gloss subscribes frt:ShipmentBooked` above the consumer's `start()` in [shipmentBookedConsumer.ts](dispatch/src/consumer/shipmentBookedConsumer.ts), `// @gloss publishes frt:ShipmentPickedUp` above [publisher.ts](dispatch/src/events/publisher.ts)'s `publishShipmentPickedUp`, and the same pair in tracking's [picked_up.rs](tracking/src/consumers/picked_up.rs) and [publisher.rs](tracking/src/events/publisher.rs). Each manifest declares what it publishes and subscribes, and drift compares.

## What the tooling makes of it

Every finding below is intentional. CI compares each repository's output with its `expected-drift.txt` and `expected-check.txt`, and the landscape with [expected-landscape.txt](expected-landscape.txt) (`showcase/workspaces.tsv`, `showcase/landscapes.tsv`). The landscape fails on any violation, gap, value-drift, dangling, rogue, orphan, stale or proposed finding, so everything shipment-core cannot close on its own must be closed by a sibling.

| Derived from code | Declared | Result |
| --- | --- | --- |
| shipment-core's code publishes only ShipmentBooked | `fleet:freight-platform` publishes all three events | shipment-core alone: **gap** on ShipmentPickedUp and ShipmentDelivered. Landscape: closed, because dispatch and tracking are `part-of` the platform and publish them |
| nothing in shipment-core links to Pickup, Dispatching, Tracking, Delivery, Route, Driver, ShipmentPickedUp, ShipmentDelivered | eight `frt:` concepts the other services realize | shipment-core alone: **orphan** ×8 (its `subscribes` and `documents` links do not count). Landscape: none |
| no test in shipment-core verifies the outbox relay | `shc:ShipmentBookedEmitter`, published | shipment-core alone: **untested**. Landscape: closed by dispatch's contract test, which `verifies shc:ShipmentBookedEmitter` |
| `StatusProjector` (shipment-core) and `TrackingQuery` (tracking) realize ShipmentVisibility; neither has a test | `frt:ShipmentVisibility` | **untested** in shipment-core (`frt:ShipmentVisibility`), in tracking (`trk:TrackingQuery`) and in the landscape (`frt:ShipmentVisibility`): nobody tests what shippers see |
| tracking's two consumers and its ping ingestor have no tests | `trk:PickedUpIntake`, `trk:PlannedStopSync`, `trk:PingIngestor` | **untested** in tracking and in the landscape |
| `dsp:ExpressPickup is-a frt:Pickup` | an extension in dispatch's namespace | a **decision request** for shipment-core's owners (not a finding kind; never fails) |
| each repository's `implements`, `represents`, `publishes`, `subscribes`, `produces`, `consumes` | each manifest | consistent: 0 violations in all three and in the landscape |
| `publishes` and `subscribes`, `produces` and `consumes` pairs on one concept across boundaries of different repositories | nothing links the repositories by hand | four derived `depends-on` edges: the landscape's **context map** |

```
$ cd shipment-core && gloss drift
○ Gaps (declared, not implemented)
  fleet:freight-platform declares publishes frt:ShipmentDelivered but nothing under it publishes it: ...  [.gloss.yaml:1]
  fleet:freight-platform declares publishes frt:ShipmentPickedUp but nothing under it publishes it: ...  [.gloss.yaml:1]
· Orphan concepts (no artifacts)
  frt:Delivery: orphan concept, no artifact links to it  [ontology/frt.gloss.yaml:45]
  ...
△ Implemented but untested
  frt:ShipmentVisibility is implemented but nothing tests or verifies it  [ontology/frt.gloss.yaml:50]
  shc:ShipmentBookedEmitter is implemented but nothing tests or verifies it (nor frt:ShipmentBooked, which it realizes)  [ontology/shc.gloss.yaml:19]
Concepts covered 75% (6/8 with an artifact and a verifier)   ...   Orphans: 8   Violations: 0   Gaps: 2   Untested: 2
gloss drift: 2 failing findings (violation,value-drift,gap,dangling)
```

## The landscape

Run from this directory, `gloss landscape` unions the three graphs by IRI, re-derives every rollup, and draws the context map from the `depends-on` edges it derives (consumer → producer):

```
$ gloss landscape shipment-core dispatch tracking
Landscape: shipment-core, dispatch, tracking

Context map (publishes → subscribes, produces → consumes across boundaries)
  dispatch:planner → shipcore:shipment-service via frt:Shipment, frt:ShipmentBooked
  shipcore:shipment-service → dispatch:planner via frt:ShipmentPickedUp
  shipcore:shipment-service → tracking:tracker via frt:ShipmentDelivered
  tracking:tracker → dispatch:planner via frt:Route, frt:ShipmentPickedUp

Ontology drift

△ Implemented but untested
  frt:ShipmentVisibility is implemented but nothing tests or verifies it  [ontology/frt.gloss.yaml:50]
  trk:PickedUpIntake is implemented but nothing tests or verifies it (nor frt:Tracking, which it realizes)  [ontology/trk.gloss.yaml:6]
  trk:PingIngestor is implemented but nothing tests or verifies it (nor frt:Tracking, which it realizes)  [ontology/trk.gloss.yaml:12]
  trk:PlannedStopSync is implemented but nothing tests or verifies it (nor frt:Tracking, which it realizes)  [ontology/trk.gloss.yaml:7]

Concepts covered 77% (17/22 with an artifact and a verifier)   Files 57% (69/121)   Orphans: 0   Rogue: 0   Violations: 0   Gaps: 0   Stale: 0   Untested: 4   Proposed links: 0   Proposed concepts: 0
```

No edge in that map was written by hand. The first line comes from dispatch consuming `frt:Shipment` (which shipment-core produces) and subscribing to `frt:ShipmentBooked` (which it publishes). `tracking → dispatch via frt:Route` comes from `produces`/`consumes` declared on implementation concepts in two different repositories. The platform's gap and the core's orphans are gone because the union holds what each repository alone could not.

Artifact paths in the landscape carry the repository name (`tracking/src/...`); ontology and manifest paths do not, so a landscape finding on `[.gloss.yaml:1]` does not say which repository's root manifest it means (FF16 in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)).

## Importing and locking

dispatch imports with a caret range on the core and a tilde range on the implementation tier; tracking takes carets on both:

```yaml
# dispatch/glossmark.yaml
imports:
  frt: { iri: https://onto.kestrel-freight.example/frt/, version: "^1.4",   source: ../shipment-core/ontology/frt.gloss.yaml }
  shc: { iri: https://onto.kestrel-freight.example/shc/, version: "~1.1.0", source: ../shipment-core/ontology/shc.gloss.yaml }
```

`gloss lock` pins what resolved, with a content hash, in [dispatch/glossmark.lock](dispatch/glossmark.lock) and [tracking/glossmark.lock](tracking/glossmark.lock), both committed:

```
$ gloss lock
gloss lock: frt: 1.4.0 (^1.4) sha256:d0a74e715ba8
gloss lock: shc: 1.1.0 (~1.1.0) sha256:81d59fcfbf43
gloss lock: written glossmark.lock; commit it
```

## Changing a published concept

[demo/published-change.sh](demo/published-change.sh) copies the three repositories into a temporary directory, makes each its own git repository, commits, and walks through what a change to the seam does on both sides. Its real output, trimmed:

**1. shipment-core shortens the delivery window from 2h to 90m**, in the Java constant and the ontology `value:` together, without a version bump. The published value change is HARD; the missing PATCH bump is SOFT:

```
shipment-core$ gloss diff --base HEAD
Ontology impact — shipment-core   base HEAD   gate HARD   criticality high
! published shc:DeliveryWindowPolicy value 2h → 90m            ontology/shc.gloss.yaml:32   [HIGH, HARD: edit to ontology; business view affected: published concept]
! namespace shc: changes require a PATCH bump but version went 1.1.0 → 1.1.0 (none)   ontology/shc.gloss.yaml      [SOFT]
Views changed: business, engineering
...
Criticality touched: shc:DeliveryWindowPolicy high (via frt:DeliveryWindow)
Version shc: 1.1.0 → 1.1.0 (requires PATCH) ✗
gloss diff: HARD changes need a human decision
```

**2. The importers notice before anyone tells them.** The lock hash no longer matches:

```
dispatch$ gloss check
glossmark.lock:1: error: imports.shc: ontology content changed since it was locked at 1.1.0 (same version number); the upstream should bump its version. Run gloss lock to accept [GM107]
```

**3. shipment-core releases `shc:` 1.1.1** (`Version shc: 1.1.0 → 1.1.1 (requires PATCH) ✓`). Both importers' ranges admit it, the lock does not, and re-pinning is a reviewed one-file diff. In the importer, taking the new pin is itself HARD, because a published concept it depends on changed:

```
dispatch$ gloss check
glossmark.lock:1: error: imports.shc: locked at 1.1.0 but resolved 1.1.1; review the upstream change, then run gloss lock [GM107]

dispatch$ gloss lock
gloss lock: frt: 1.4.0 (^1.4) sha256:d0a74e715ba8
gloss lock: shc: 1.1.1 (~1.1.0) sha256:eb50c779355e
...
dispatch$ git diff --unified=0 glossmark.lock
-        version: 1.1.0
+        version: 1.1.1
-        hash: sha256:81d59fcfbf434291273dfd1716164de5fac25b85af717c2450da89c073e664f8
+        hash: sha256:eb50c779355eeca0b810125c0d41333d58a3f7e9bbe29d624736b3e246ebb4f4

dispatch$ gloss diff --base HEAD
Ontology impact — dispatch   base HEAD   gate HARD   criticality high
! published shc:DeliveryWindowPolicy value 2h → 90m     /tmp/tmp.MTpHnuNlZa/shipment-core/ontology/shc.gloss.yaml:32   [HIGH, HARD: edit to ontology; business view affected: published concept]
...
gloss diff: HARD changes need a human decision
```

tracking is where this matters: its lateness check hard-codes the window (`DELIVERY_WINDOW: Duration = Duration::from_secs(2 * 60 * 60)` in [window.rs](tracking/src/delivery/window.rs)). Binding that constant to the upstream value does not work in v0.1.0: `gloss check` accepts `// @gloss publishes-value shc:DeliveryWindowPolicy scope=line` above it, but editing the constant only marks that link stale, and changing the upstream value reports nothing. The GM107 error and `gloss impact` are the prompt:

```
tracking$ gloss impact tests/window.rs
tests/window.rs  [HARD, tracking:tracker, criticality high]
  @gloss verifies shc:DeliveryWindowPolicy  (line 1)
  ...
  shc:DeliveryWindowPolicy (constraint, implementation, high): PUBLISHED as frt:DeliveryWindow; realizes frt:DeliveryWindow
  → shc:DeliveryWindowPolicy is on the published seam: changes alter the business view (HARD)
```

**4. The own-subject rule.** dispatch tries to give an imported concept a part, and to define a concept in `frt:`:

```
dispatch$ gloss check
ontology/dsp.gloss.yaml:26: error: dsp:PickupManifest has-part frt:Parcel makes imported frt:Parcel the subject of a part-of statement; extend, never mutate (own-subject rule). Write frt:Parcel part-of dsp:PickupManifest instead [GM400]
...
ontology/dsp.gloss.yaml:27: error: frt:ExpressPickup: concept defined in namespace dsp: belongs to frt:, which this repo does not own (own-subject rule) [GM401]
```

The GM400 message suggests a statement whose subject is again `frt:`; writing it gives GM401.

<a id="the-published-seam-holds"></a>**5. The published seam holds.** A tracking test references the published `shc:LabelSpec` and the unpublished `shc:LabelRenderer`. Only the second is refused. When shipment-core's `shc.gloss.yaml` drops its `tier: implementation` line (and tracking re-pins), the same reference passes:

```
tracking$ gloss check
tests/scan_parse.rs:1: error: shc:LabelRenderer is an unpublished concept of imported namespace shc: and cannot be referenced; only published concepts cross repos [GM230]

# the same reference after shipment-core drops tier: implementation from shc.gloss.yaml (tracking re-pinned)
tracking$ gloss check
gloss check: 0 errors, 0 warnings
```

**6. A MAJOR change.** `frt:Tracking` becomes a capability and `frt:` goes to 2.0.0. The retype and the MAJOR bump are both HARD, and both importers' ranges now exclude the core:

```
shipment-core$ gloss diff --base HEAD
...
! namespace frt: MAJOR change (removal, retype, or is-a/part-of change)   ontology/frt.gloss.yaml      [HARD: MAJOR bump]
! frt:Tracking kind process → capability                       ontology/frt.gloss.yaml:41   [HARD: edit to ontology]
...
Version frt: 1.4.0 → 2.0.0 (requires MAJOR) ✓
gloss diff: HARD changes need a human decision

dispatch$ gloss check
glossmark.yaml:1: error: imports.frt: requires ^1.4 but the resolved ontology is 2.0.0 (../shipment-core/ontology/frt.gloss.yaml) [GM106]
glossmark.lock:1: error: imports.frt: locked at 1.4.0 but resolved 2.0.0; review the upstream change, then run gloss lock [GM107]
```

## Publishing

`gloss publish` writes what shipment-core offers the rest of the company: one directory per owned namespace. [demo/publish.sh](demo/publish.sh) runs it into a temporary directory (`dist/` is never committed) and summarises the files:

```
$ gloss publish -o $OUT
gloss publish: frt: (core 1.4.0) → $OUT/frt
gloss publish: shc: (implementation 1.1.0) → $OUT/shc

$ find $OUT -type f | sort
$OUT/frt/frt.gloss.yaml
$OUT/frt/ontology.jsonld
$OUT/shc/graph.jsonl
$OUT/shc/ontology.jsonld
$OUT/shc/shc.gloss.yaml

$ # frt/ontology.jsonld: the whole core tier
21 concepts
  frt:Booking                  process     {"publishes": "frt:ShipmentBooked"}
  ...
$ # shc/ontology.jsonld: only the published implementation concepts
4 concepts
  shc:DeliveryWindowPolicy     constraint  {"gm:value": "2h", "published-as": ["frt:DeliveryWindow", "frt:DeliveryWindow"], "realizes": "frt:DeliveryWindow"}
  shc:LabelSpec                constraint  {"gm:value": "ZPL II, 4x6 in, 203 dpi", "published-as": ["frt:LabelFormat", "frt:LabelFormat"], "realizes": "frt:LabelFormat"}
  shc:OnTimeRateCalculator     measure     {"gm:value": "95%", "published-as": ["frt:OnTimeDeliveryRate", "frt:OnTimeDeliveryRate"], "realizes": "frt:OnTimeDeliveryRate"}
  shc:ShipmentBookedEmitter    process     {"published-as": ["frt:ShipmentBooked", "frt:ShipmentBooked"], "publishes": "frt:ShipmentBooked", "realizes": "frt:ShipmentBooked"}

$ # shc/graph.jsonl: the boundaries and links that reference them
137 records: {'boundary': 2, 'concept': 19, 'context': 1, 'edge': 115}
shc: concepts: ['shc:DeliveryWindowPolicy', 'shc:LabelSpec', 'shc:OnTimeRateCalculator', 'shc:ShipmentBookedEmitter']
boundaries: ['fleet:freight-platform', 'shipcore:shipment-service']
...
$ grep -c '^  [A-Z]' $OUT/shc/shc.gloss.yaml   # the copied ontology file still lists every shc: concept
9
```

The JSON-LD and the graph keep the four published concepts and drop the five unpublished ones. The copied `shc.gloss.yaml` keeps all nine, and `published-as` appears twice per concept in the JSON-LD (FF14, FF15 in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)).

## Run it

```sh
export GLOSS=$PWD/../../.tools/bin/gloss                     # from this directory, after scripts/install-gloss.sh
(cd shipment-core && $GLOSS check && $GLOSS drift)            # the gaps, orphans and untested above
(cd dispatch && $GLOSS check && $GLOSS drift)
(cd tracking && $GLOSS check && $GLOSS drift)
$GLOSS landscape shipment-core dispatch tracking              # the union: no gaps, no orphans
demo/published-change.sh                                      # HARD on the seam, GM107, re-lock, GM400, GM230, MAJOR
demo/publish.sh                                               # gloss publish, summarised
```

## How it was adopted

The three codebases were written first, with no GlossMark files. Each was then adopted the way a new user would, shipment-core first because the others import it: `gloss init --dry-run` (guessed `sc:`/`sci:`, `di:`/`dii:` and `tr:`/`tri:`), `gloss init` with `--core`/`--impl` overrides, the init-written workflow and hook files deleted, the core and implementation tiers written by hand, `gloss suggest --write` (shipment-core 50 proposals: 21 kept, 7 retargeted; dispatch 81: 4 kept, 4 retargeted; tracking 85: 8 kept, 5 retargeted), hand-written markers for docs, tests, Prisma models and every inline `publishes`/`subscribes`, then `gloss lock` in both importers, `gloss accept --policy` and `gloss accept --all`. `gloss init` has no importer mode: in dispatch and tracking it scaffolded a core namespace, which was deleted and replaced with `imports:`.

File-scope test markers went stale when accepted (F-ADOPT-8 in [lab/FINDINGS-ADOPTION.md](../../lab/FINDINGS-ADOPTION.md)) and were re-recorded as accepted the way clinic-booking does. Every friction point is in the freight-federation rows of [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md). The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them yet.
