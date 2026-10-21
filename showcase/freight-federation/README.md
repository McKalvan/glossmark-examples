# Kestrel Freight: three repositories, one core

**Shape:** three sibling repositories that share one core tier. **Shows:** the published seam (`published: { as: }`) between an implementation tier and the business view and across repositories, importing a core and an implementation namespace with semver ranges, `gloss lock` and `glossmark.lock`, extension under the own-subject rule (`is-a` and `part-of` onto imported concepts), `has-part`, events with `publishes`/`subscribes` inline, in the ontology and in manifests, `gloss landscape` with its context map and cross-repo drift, a HARD gate on a published change and on a MAJOR bump, and `gloss publish`.

Kestrel Freight moves parcels by road. A shipper books a shipment; the shipment service prints its labels, picks a carrier and promises a two-hour delivery window. Dispatch plans which driver collects it and when. Once it is collected, tracking follows the driver's GPS pings and depot scans until the driver arrives at the delivery address, and records the proof of delivery. Every delivery counts toward the on-time rate, the measure operations watch.

| Repository | What | Stack | Owns | Imports |
| --- | --- | --- | --- | --- |
| [shipment-core](shipment-core) | Booking, labels, carrier assignment, the delivery-window promise, the on-time rate, the ShipmentBooked outbox | Java 21, Spring Boot 3, JPA, Flyway, Kafka, JUnit 5 | `frt:` (core), `shc:` (implementation) | |
| [dispatch](dispatch) | Pickup planning: driver matching, route optimisation, express pickups, pickup confirmation | TypeScript, Node 20, Fastify, kafkajs, Prisma, vitest | `dsp:` | `frt: ^1.4`, `shc: ~1.1.0` |
| [tracking](tracking) | GPS pings, scans, geofence arrival, proof of delivery, the tracking API | Rust, axum, sqlx, rdkafka, cargo tests | `trk:` | `frt: ^1.3`, `shc: ^1.1` |

The three directories are **separate repositories in all but location**: each has its own `glossmark.yaml`, ledger, graph and CI workflow, and the importers reach the core through a relative path (`source: ../shipment-core/ontology/frt.gloss.yaml`). The pinned GlossMark, like v0.1.0, accepts local paths only; `git+` and `https://` sources are parsed and rejected. Once GlossMark's remote import fetcher ships, the three directories become three repositories and the `source:` lines become git references.

With v0.1.0, `dispatch/.glossmark/graph.jsonl` and `tracking/.glossmark/graph.jsonl` recorded the imported ontology files by absolute path, the path of the checkout that built them, although `source:` is relative ([F-SPLIT-1](../../lab/monolith-decomposition/FINDINGS.md#f-split-1-graphjsonl-records-imported-ontologies-with-absolute-paths), FF22). The graphs built by the pinned GlossMark record `../shipment-core/ontology/frt.gloss.yaml` as written; no committed graph holds an absolute path. `scripts/check-workspace.sh` still replaces the checkout prefix before it compares graphs, which is now a no-op here.

`gloss lock` now also vendors each locked import under `.glossmark/imports/` (`frt@1.4.0.gloss.yaml`, `shc@1.1.0.gloss.yaml`), and commands resolve the import from that copy while its hash matches the lock. The committed locks were written by v0.1.0 and have no vendored copies; the importers resolve `source:` directly until someone re-runs `gloss lock` and commits `.glossmark/imports/`.

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

`shc.gloss.yaml` says `tier: implementation` at the top. Without that line, an importer does not know `shc:` is an implementation namespace, and GM230 (an unpublished concept referenced across repositories) never fires. The pinned GlossMark says so with a GM113 warning; v0.1.0 was silent. See [the seam demo](#the-published-seam-holds) below.

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
| [shipment-core/service/.gloss.yaml](shipment-core/service/.gloss.yaml) | `shipcore:shipment-service` | `part-of` the platform; `realizes` eight `shc:` concepts; `holds` five entities, plus `ShipmentBooked` (the outbox table keeps it until the relay sends it) and `OnTimeDeliveryRate` (the stored delivery outcomes it is computed from), because `represents` lifts to `holds` on any kind of concept (GlossMark ADR 0013); `produces` Shipment and ShippingLabel; `publishes` ShipmentBooked; `subscribes` ShipmentPickedUp and ShipmentDelivered |
| [dispatch/.gloss.yaml](dispatch/.gloss.yaml) | `dispatch:planner` | `part-of` the platform; `consumes` Shipment, `produces` Route, `subscribes` ShipmentBooked, `publishes` ShipmentPickedUp; `generated:` Prisma migrations; `allowed: [derived, shc:ShipmentBookedEmitter]` for the contract test |
| [tracking/.gloss.yaml](tracking/.gloss.yaml) | `tracking:tracker` | `part-of` the platform; `consumes` Route, `subscribes` ShipmentPickedUp, `publishes` ShipmentDelivered; `allowed: [derived, shc:DeliveryWindowPolicy]` for the lateness test |

`fleet:` is a boundary prefix all three `glossmark.yaml` files declare, so `part-of: fleet:freight-platform` in dispatch and tracking names the boundary that shipment-core defines. Each repository has its own boundary prefix under its own `repo-iri`.

Events are linked three ways. shipment-core declares them on implementation concepts (`shc:ShipmentBookedEmitter publishes frt:ShipmentBooked`, `shc:StatusProjector subscribes` the other two). Since GlossMark ADR 0026 a concept's flows are intent: drift compares them with the manifest, but only the code's own markers close a gap. So the code is marked too: `// @gloss publishes frt:ShipmentBooked` in [OutboxRelay.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/events/OutboxRelay.java), `// @gloss subscribes frt:ShipmentPickedUp, frt:ShipmentDelivered` in [ShipmentStatusListener.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/events/ShipmentStatusListener.java), and `produces frt:Shipment` and `produces frt:ShippingLabel` in [BookingService.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/booking/BookingService.java) and [LabelRenderer.java](shipment-core/service/src/main/java/com/kestrelfreight/shipment/label/LabelRenderer.java). The same change added `consumes frt:Shipment` to dispatch's [shipmentBookedConsumer.ts](dispatch/src/consumer/shipmentBookedConsumer.ts), `produces frt:Route` to its [routeOptimizer.ts](dispatch/src/planning/routeOptimizer.ts) and `consumes frt:Route` to tracking's [route_planned.rs](tracking/src/consumers/route_planned.rs). dispatch and tracking mark the code that touches the topic inline: `// @gloss subscribes frt:ShipmentBooked` above the consumer's `start()` in [shipmentBookedConsumer.ts](dispatch/src/consumer/shipmentBookedConsumer.ts), `// @gloss publishes frt:ShipmentPickedUp` above [publisher.ts](dispatch/src/events/publisher.ts)'s `publishShipmentPickedUp`, and the same pair in tracking's [picked_up.rs](tracking/src/consumers/picked_up.rs) and [publisher.rs](tracking/src/events/publisher.rs). Each manifest declares what it publishes and subscribes, and drift compares.

## What the tooling makes of it

Every finding below is intentional. CI compares each repository's output with its `expected-drift.txt` and `expected-check.txt`, and the landscape with [expected-landscape.txt](expected-landscape.txt) (`showcase/workspaces.tsv`, `showcase/landscapes.tsv`). The landscape fails on any gap, value-drift, dangling, rogue, orphan, stale or proposed finding, so everything shipment-core cannot close on its own must be closed by a sibling. `violation` left the landscape's fail-on and the fail-on of dispatch and tracking when the pin moved past v0.1.0: their event payload types now derive `holds` violations (below), which this example documents. dispatch and tracking therefore no longer run the GlossMark Action, whose drift step fails on any violation.

| Derived from code | Declared | Result |
| --- | --- | --- |
| shipment-core's code publishes only ShipmentBooked, and subscribes to the other two | `fleet:freight-platform` publishes all three events | shipment-core alone: **gap** on ShipmentPickedUp and ShipmentDelivered, which says `its code subscribes to it instead: declare subscribes, or change the marker`. Landscape: closed, because dispatch and tracking are `part-of` the platform and publish them |
| nothing in shipment-core links to Pickup, Dispatching, Tracking, Delivery, Route, Driver by code | six `frt:` concepts the other services realize | shipment-core alone: **orphan** ×6 (a `documents` link does not count, and the message says so). Landscape: none. With v0.1.0 there were eight: ShipmentPickedUp and ShipmentDelivered are no longer orphans because `ShipmentStatusListener` now subscribes to them. Even without that marker the pinned GlossMark would not report them, because it counts `shc:StatusProjector`'s intent as reach while the gap on the same concept says intent does not count (GlossMark #173) |
| no test in shipment-core verifies the outbox relay | `shc:ShipmentBookedEmitter`, published | shipment-core alone: **untested**; the line adds that `frt:ShipmentBooked`, the event it realizes, has no test either. Landscape: closed by dispatch's contract test, which `verifies shc:ShipmentBookedEmitter` |
| `StatusProjector` (shipment-core) and `TrackingQuery` (tracking) realize ShipmentVisibility; neither has a test | `frt:ShipmentVisibility` | **untested** in shipment-core (`frt:ShipmentVisibility`), in tracking (`trk:TrackingQuery`) and in the landscape (`frt:ShipmentVisibility`): nobody tests what shippers see |
| tracking's two consumers and its ping ingestor have no tests | `trk:PickedUpIntake`, `trk:PlannedStopSync`, `trk:PingIngestor` | **untested** in tracking and in the landscape |
| `dsp:ExpressPickup is-a frt:Pickup` | an extension in dispatch's namespace | a **decision request** for shipment-core's owners (not a finding kind; never fails) |
| dispatch's `ShipmentBooked` zod schema and `ShipmentPickedUp` payload type, tracking's `ShipmentDelivered` and `ShipmentPickedUp` payload types, each `represents` the event | dispatch `holds [Driver, Route]`, tracking `holds [Route, Shipment]` | **violation** ×2 in dispatch, ×2 in tracking, ×4 in the landscape: `represents` lifts to `holds` on an event too (ADR 0013), so a message's shape reads as stored data. The events are not added to `holds:`, which would say the services store them; GlossMark #172 proposes not deriving `holds` for an event the boundary publishes or subscribes to. v0.1.0 reported none |
| each repository's `implements`, other `represents`, `publishes`, `subscribes`, `produces`, `consumes` | each manifest | consistent. shipment-core declares the outbox's `ShipmentBooked` and the stored outcomes behind `OnTimeDeliveryRate` under `holds`, which is what that data is |
| `publishes` and `subscribes`, `produces` and `consumes` pairs on one concept across boundaries of different repositories | nothing links the repositories by hand | four derived `depends-on` edges: the landscape's **context map** |

```
$ cd shipment-core && gloss drift
Ontology drift

○ Gaps (declared, not implemented)
  fleet:freight-platform declares publishes frt:ShipmentDelivered but nothing under it publishes it; its code subscribes to it instead: declare subscribes, or change the marker  [.gloss.yaml:1]
  fleet:freight-platform declares publishes frt:ShipmentPickedUp but nothing under it publishes it; its code subscribes to it instead: declare subscribes, or change the marker  [.gloss.yaml:1]

· Orphan concepts (no artifacts)
  frt:Delivery: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:45]
  frt:Dispatching: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:32]
  frt:Driver: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:21]
  frt:Pickup: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:37]
  frt:Route: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:20]
  frt:Tracking: orphan concept, no code links to it (a documents or instructs link does not count)  [ontology/frt.gloss.yaml:41]

△ Implemented but untested
  frt:ShipmentVisibility is implemented but nothing tests or verifies it  [ontology/frt.gloss.yaml:50]
  shc:ShipmentBookedEmitter is implemented but nothing tests or verifies it (nor frt:ShipmentBooked, which it realizes)  [ontology/shc.gloss.yaml:19]

Concepts covered 75% (6/8 with an artifact and a verifier)   Orphans: 6   Rogue: 0   Violations: 0   Gaps: 2   Stale: 0   Untested: 2   Proposed links: 0   Proposed concepts: 0
gloss drift: 2 failing findings (violation,value-drift,gap,dangling,overdue)
```

## The landscape

Run from this directory, `gloss landscape` unions the three graphs by IRI, re-derives every rollup, and draws the context map from the `depends-on` edges it derives (consumer → producer):

```
$ gloss landscape shipment-core dispatch tracking
Landscape: shipment-core, dispatch, tracking

Context map (consumer → producer: depends on what it subscribes to or consumes)
  dispatch:planner → shipcore:shipment-service via frt:Shipment, frt:ShipmentBooked
  shipcore:shipment-service → dispatch:planner via frt:ShipmentPickedUp
  shipcore:shipment-service → tracking:tracker via frt:ShipmentDelivered
  tracking:tracker → dispatch:planner via frt:Route, frt:ShipmentPickedUp

Imports
  importer namespace range  locked resolved status
  dispatch frt       ^1.4   1.4.0  1.4.0    ok
  dispatch shc       ~1.1.0 1.1.0  1.1.0    ok
  tracking frt       ^1.3   1.4.0  1.4.0    ok
  tracking shc       ^1.1   1.1.0  1.1.0    ok

Ontology drift

✗ Violations (boundary exceeds its declared capability)
  dispatch:planner holds frt:ShipmentBooked but declares holds {frt:Driver, frt:Route}  [dispatch/src/consumer/schemas.ts:35]
  dispatch:planner holds frt:ShipmentPickedUp, which its declared holds does not cover (sets on dispatch:planner frt:ShipmentBooked)  [dispatch/src/events/types.ts:57]
  tracking:tracker holds frt:ShipmentDelivered but declares holds {frt:Route, frt:Shipment}  [tracking/src/events/types.rs:62]
  tracking:tracker holds frt:ShipmentPickedUp, which its declared holds does not cover (sets on tracking:tracker frt:ShipmentDelivered)  [tracking/src/events/types.rs:29]

△ Implemented but untested
  frt:ShipmentVisibility is implemented but nothing tests or verifies it  [shipment-core/ontology/frt.gloss.yaml:50]
  trk:PickedUpIntake is implemented but nothing tests or verifies it; frt:Tracking, which it realizes, counts as tested only because trk:ScanIngestor is tested  [tracking/ontology/trk.gloss.yaml:6]
  trk:PingIngestor is implemented but nothing tests or verifies it; frt:Tracking, which it realizes, counts as tested only because trk:ScanIngestor is tested  [tracking/ontology/trk.gloss.yaml:12]
  trk:PlannedStopSync is implemented but nothing tests or verifies it; frt:Tracking, which it realizes, counts as tested only because trk:ScanIngestor is tested  [tracking/ontology/trk.gloss.yaml:7]

Concepts covered 77% (17/22 with an artifact and a verifier)   Orphans: 0   Rogue: 0   Violations: 4   Gaps: 0   Stale: 0   Untested: 4   Proposed links: 0   Proposed concepts: 0
```

The pinned GlossMark adds the `Imports` table: each importer's range, locked and resolved version. No edge in that map was written by hand. The first line comes from dispatch consuming `frt:Shipment` (which shipment-core produces) and subscribing to `frt:ShipmentBooked` (which it publishes). `tracking → dispatch via frt:Route` comes from `produces`/`consumes` declared on implementation concepts in two different repositories. The platform's gap and the core's orphans are gone because the union holds what each repository alone could not. The four `holds` violations are each repository's own, unchanged by the union.

Paths in the landscape carry the repository name, ontology paths included (`tracking/ontology/trk.gloss.yaml:6`). With v0.1.0 ontology and manifest paths did not, so a landscape finding on `[.gloss.yaml:1]` did not say which repository's root manifest it meant (FF16 in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)).

## Importing and locking

dispatch imports with a caret range on the core and a tilde range on the implementation tier; tracking takes carets on both:

```yaml
# dispatch/glossmark.yaml
imports:
  frt: { iri: https://onto.kestrel-freight.example/frt/, version: "^1.4",   source: ../shipment-core/ontology/frt.gloss.yaml }
  shc: { iri: https://onto.kestrel-freight.example/shc/, version: "~1.1.0", source: ../shipment-core/ontology/shc.gloss.yaml }
```

`gloss lock` pins what resolved, with a content hash, in [dispatch/glossmark.lock](dispatch/glossmark.lock) and [tracking/glossmark.lock](tracking/glossmark.lock), both committed. With the pinned GlossMark it also writes the vendored copies (a run on a copy of dispatch):

```
$ gloss lock
gloss lock: frt: 1.4.0 (^1.4) sha256:d0a74e715ba8
gloss lock: shc: 1.1.0 (~1.1.0) sha256:81d59fcfbf43
gloss lock: written glossmark.lock and .glossmark/imports/; commit them
```

## Changing a published concept

[demo/published-change.sh](demo/published-change.sh) copies the three repositories into a temporary directory, makes each its own git repository, commits, and walks through what a change to the seam does on both sides. Its real output, trimmed:

**1. shipment-core shortens the delivery window from 2h to 90m**, in the Java constant and the ontology `value:` together, without a version bump. The published value change is HARD, and so is the missing PATCH bump (it was SOFT in v0.1.0):

```
shipment-core$ gloss diff --base HEAD
Ontology impact — shipment-core   base HEAD   gate HARD   criticality high
! published shc:DeliveryWindowPolicy value 2h → 90m            ontology/shc.gloss.yaml:32   [HIGH, HARD: edit to ontology; business view affected: published concept]
! namespace shc: changes require a PATCH bump but version went 1.1.0 → 1.1.0 (none)   ontology/shc.gloss.yaml      [HARD: semver: bump the namespace version; importers' ranges rely on it]
Views changed: business, engineering
Concepts covered 75% → 75%   Files 61% → 61%   Orphans: 6 (frt:Delivery, frt:Dispatching, frt:Driver, …)   Rogue: 0   Proposed links: 0   Proposed concepts: 0   Stale: 0
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
gloss lock: written glossmark.lock and .glossmark/imports/; commit them
...
dispatch$ git diff --unified=0 glossmark.lock
-        version: 1.1.0
+        version: 1.1.1
-        hash: sha256:81d59fcfbf434291273dfd1716164de5fac25b85af717c2450da89c073e664f8
+        hash: sha256:eb50c779355eeca0b810125c0d41333d58a3f7e9bbe29d624736b3e246ebb4f4

dispatch$ gloss diff --base HEAD
Ontology impact — dispatch   base HEAD   gate HARD   criticality high
! published shc:DeliveryWindowPolicy value 2h → 90m     .glossmark/imports/shc@1.1.1.gloss.yaml:32   [HIGH, HARD: edit to ontology; business view affected: published concept]
Views changed: business, engineering      Rollup: dispatch:planner holds {frt:ShipmentBooked, frt:ShipmentPickedUp} ⊄ declared {frt:Driver, frt:Route}  ✗
Concepts covered 100% → 100%   Files 56% → 56%   Orphans: 0   Rogue: 0   Proposed links: 0   Proposed concepts: 0   Stale: 0
Criticality touched: shc:DeliveryWindowPolicy high (via frt:DeliveryWindow)
gloss diff: HARD changes need a human decision
```

The importer's diff names the vendored copy (`.glossmark/imports/shc@1.1.1.gloss.yaml:32`); with v0.1.0 it printed the absolute path of the upstream file (FF17). Its rollup line also shows dispatch's documented `holds` violation.

tracking is where this matters: its lateness check hard-codes the window (`DELIVERY_WINDOW: Duration = Duration::from_secs(2 * 60 * 60)` in [window.rs](tracking/src/delivery/window.rs)). Binding that constant to the upstream value does not work, with the pinned GlossMark as with v0.1.0: `gloss check` accepts `// @gloss publishes-value shc:DeliveryWindowPolicy scope=line` above it, but editing the constant only marks that link stale, and the marker now also adds a `realizes` violation in tracking, because `publishes-value` lifts as `implements` (ADR 0017). The GM107 error and `gloss impact` are the prompt:

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
dispatch$ gloss check
ontology/dsp.gloss.yaml:26: error: dsp:PickupManifest has-part frt:Parcel makes imported frt:Parcel the subject of a part-of statement; extend, never mutate (own-subject rule). Declare a dsp: concept that is-a frt:Parcel and part-of dsp:PickupManifest, or ask frt:'s owner to add the edge [GM400]
ontology/dsp.gloss.yaml:27: warning: dsp:frt:ExpressPickup: concept names are PascalCase [GM302]
ontology/dsp.gloss.yaml:27: error: frt:ExpressPickup: concept defined in namespace dsp: belongs to frt:, which this repo does not own (own-subject rule) [GM401]
gloss check: 2 errors, 1 warning
```

The GM400 message now suggests a `dsp:` concept that `is-a frt:Parcel`, which the own-subject rule allows; in v0.1.0 it suggested a statement whose subject was again `frt:`, which gave GM401. The GM302 warning names the concept `dsp:frt:ExpressPickup`, which reads as a doubled prefix.

<a id="the-published-seam-holds"></a>**5. The published seam holds.** A tracking test references the published `shc:LabelSpec` and the unpublished `shc:LabelRenderer`. Only the second is refused. When shipment-core's `shc.gloss.yaml` drops its `tier: implementation` line and tracking runs `gloss lock`, the reference is still refused: the content changed under the same version, so the lock keeps resolving the vendored copy, which still says `tier: implementation`, and GM116 asks for `gloss lock --update`. In v0.1.0 the same steps made the reference pass. After `gloss lock --update` the copy has no `tier:` either, and `gloss check` warns (GM113) that `shc:` is read as core and GM230 is not enforced:

```
tracking$ gloss check
tests/scan_parse.rs:1: error: shc:LabelRenderer is an unpublished concept of imported namespace shc: and cannot be referenced; only published concepts cross repos [GM230]
gloss check: 1 error, 0 warnings

# the same reference after shipment-core drops tier: implementation from shc.gloss.yaml (tracking re-pinned)

tracking$ gloss check
glossmark.lock:1: warning: imports.shc: upstream content changed under the same version 1.1.1 (it should bump); still resolving the pinned copy. Review it, then run gloss lock --update [GM116]
tests/scan_parse.rs:1: error: shc:LabelRenderer is an unpublished concept of imported namespace shc: and cannot be referenced; only published concepts cross repos [GM230]
gloss check: 1 error, 1 warning
```

**6. A MAJOR change.** `frt:Tracking` becomes a capability and `frt:` goes to 2.0.0. The retype and the MAJOR bump are both HARD. Both importers' ranges now exclude the new core, but the importers keep working: they resolve the pinned 1.4.0 copy and `gloss check` warns (GM116). In v0.1.0 they failed with GM106 and GM107.

```
shipment-core$ gloss diff --base HEAD
Ontology impact — shipment-core   base HEAD   gate HARD
! glossmark.yaml changed                                       glossmark.yaml               [HARD: edit to ontology/ or manifests]
! namespace frt: MAJOR change (removal, retype, or is-a/part-of change)   ontology/frt.gloss.yaml      [HARD: MAJOR bump]
! frt:Tracking kind process → capability                       ontology/frt.gloss.yaml:41   [HARD: edit to ontology]
Views changed: business, engineering
Concepts covered 75% → 75%   Files 61% → 61%   Orphans: 6 (frt:Delivery, frt:Dispatching, frt:Driver, …)   Rogue: 0   Proposed links: 0   Proposed concepts: 0   Stale: 0
Version frt: 1.4.0 → 2.0.0 (requires MAJOR) ✓
gloss diff: HARD changes need a human decision

dispatch$ gloss check
glossmark.lock:1: warning: imports.frt: 2.0.0 available, outside ^1.4; still resolving the pinned 1.4.0. Review it, then run gloss lock --update [GM116]
gloss check: 0 errors, 1 warning

tracking$ gloss check
glossmark.lock:1: warning: imports.frt: 2.0.0 available, outside ^1.3; still resolving the pinned 1.4.0. Review it, then run gloss lock --update [GM116]
gloss check: 0 errors, 1 warning
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
  frt:Carrier                  entity      
  frt:CarrierAssignment        process     
  frt:Consignment              entity      
  frt:Delivery                 process     {"publishes": "frt:ShipmentDelivered"}
  frt:DeliveryWindow           constraint  
  frt:Dispatching              process     
  frt:Driver                   entity      
  frt:LabelFormat              constraint  
  frt:Labelling                process     
  frt:OnTimeDeliveryRate       measure     
  frt:Parcel                   entity      
  frt:Pickup                   process     {"publishes": "frt:ShipmentPickedUp"}
  frt:Route                    entity      
  frt:Shipment                 entity      
  frt:ShipmentBooked           event       
  frt:ShipmentDelivered        event       
  frt:ShipmentPickedUp         event       
  frt:ShipmentVisibility       capability  
  frt:ShippingLabel            entity      
  frt:Tracking                 process     

$ # shc/ontology.jsonld: only the published implementation concepts
4 concepts
  shc:DeliveryWindowPolicy     constraint  {"gm:value": "2h", "published-as": "frt:DeliveryWindow", "realizes": "frt:DeliveryWindow"}
  shc:LabelSpec                constraint  {"gm:value": "ZPL II, 4x6 in, 203 dpi", "published-as": "frt:LabelFormat", "realizes": "frt:LabelFormat"}
  shc:OnTimeRateCalculator     measure     {"gm:value": "95%", "published-as": "frt:OnTimeDeliveryRate", "realizes": "frt:OnTimeDeliveryRate"}
  shc:ShipmentBookedEmitter    process     {"published-as": "frt:ShipmentBooked", "publishes": "frt:ShipmentBooked", "realizes": "frt:ShipmentBooked"}

$ # shc/graph.jsonl: the boundaries and links that reference them
153 records: {'boundary': 2, 'concept': 19, 'context': 1, 'edge': 131}
shc: concepts: ['shc:DeliveryWindowPolicy', 'shc:LabelSpec', 'shc:OnTimeRateCalculator', 'shc:ShipmentBookedEmitter']
boundaries: ['fleet:freight-platform', 'shipcore:shipment-service']
edges: consumes (derived) 2, holds (declared) 7, holds (derived) 24, part-of (declared) 1, produces (declared) 2, produces (derived) 8, published-as (declared) 4, publishes (declared) 5, publishes (derived) 6, realizes (declared) 8, realizes (derived) 24, represents (derived) 24, subscribes (declared) 2, subscribes (derived) 8, verifies (derived) 6

$ grep -c '^  [A-Z]' $OUT/shc/shc.gloss.yaml   # the copied ontology file still lists every shc: concept
4
```

The JSON-LD, the graph and the copied `shc.gloss.yaml` keep the four published concepts and drop the five unpublished ones, and `published-as` appears once per concept. With v0.1.0 the copied file kept all nine and the JSON-LD listed `published-as` twice (FF14, FF15 in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md)).

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

With v0.1.0, file-scope test markers went stale when accepted (F-ADOPT-8 in [lab/FINDINGS-ADOPTION.md](../../lab/FINDINGS-ADOPTION.md)) and were re-recorded as accepted the way clinic-booking does. Every friction point is in the freight-federation rows of [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md). The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them yet.
