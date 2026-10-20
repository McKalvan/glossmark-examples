# Tidewater Mutual: claims events

**Shape:** an event-driven system. **Shows:** `publishes`, `subscribes`, `produces` and `consumes` at all three levels (inline markers, ontology concepts, boundary manifests); a system manifest that declares the general `ClaimEvent` while three containers publish eleven event types; a five-level event taxonomy and a four-level claim taxonomy; Avro schemas marked through `.avsc.gloss` sidecars (`scope=range`); an AsyncAPI contract marked per channel (`scope=block`); `constrains`, `reverses`, `attaches-to` and a custom `escalates-to` relation; a documented violation, gap and value-drift.

Tidewater Mutual insures homes and cars. A policyholder files a claim through the intake API; the claim becomes an event on Kafka. Fraud screening scores every new claim and raises an alert for suspicious ones. Assessment reads filed claims, withdrawals and fraud alerts, then approves (and authorizes the payout), denies, or refers the claim to an adjuster. The payout notifier emails the policyholder when their money is on its way.

| Path | What | Stack |
| --- | --- | --- |
| `services/claim-intake` | Files and withdraws claims, publishes `claims.filed.v1` and `claims.lifecycle.v1` | Kotlin, Ktor, Exposed, transactional Kafka producer |
| `services/assessment` | Decides filed claims; publishes decisions, payouts and referrals | Python 3.12, confluent-kafka |
| `services/fraud-screening` | Scores filed claims, publishes `fraud.alerts.v1` | Kotlin, Kafka Streams |
| `services/payout-notifier` | Emails policyholders about authorized payouts | Go, confluent-kafka-go, SES |
| `schemas` | Avro schemas and the Schema Registry subject list | Avro (`.avsc`), `subjects.yaml`, `register.sh` |
| `contracts` | The AsyncAPI 3.0 contract and its test | AsyncAPI YAML, pytest |
| `platform/kafka` | Cluster, topics and per-service users | Strimzi `Kafka`, `KafkaTopic`, `KafkaUser` CRDs |
| `deploy/k8s` | Deployments and the shared ConfigMap | Kubernetes YAML, Kustomize |
| `docs` | Event catalog and the referral runbook | Markdown |

Each service has its own consumer-group configuration (`config/consumer-group.yaml`, or `streams.properties` for Kafka Streams), a Dockerfile and tests. The code is realistic but inert: it is never built here.

## The two tiers

**Core, `claim:`** ([ontology/claim.gloss.yaml](ontology/claim.gloss.yaml)) is what a claims manager would recognise. Entities: `Policy`, `Claim` and its subtypes, `LossEvidence`, `Assessment`, `Payout`. Events: `ClaimEvent` and its family. Processes: `ClaimFiling`, `ClaimWithdrawal`, `ClaimAssessment`, `AdjusterReview`, `FraudScreening`, `SpecialInvestigation`, `PayoutNotification`. Rules: `FilingWindow`, `AutoApprovalLimit`, `FraudReferralThreshold`. Every process says what it `publishes`, `subscribes` to, `produces` and `consumes`.

**Implementation, `tide:`** ([ontology/tide.gloss.yaml](ontology/tide.gloss.yaml)) is what an engineer would name: the four deployable `system-type`s, the handlers and pipelines that realize the core processes, three published rules, and eight `internal` Kafka resources (the cluster, six topics, the service identities).

Two taxonomies carry the system-level rollup:

```
ClaimEvent                                   Claim
├── ClaimLifecycleEvent                      ├── MotorClaim
│   ├── ClaimFiled                           └── PropertyClaim
│   │   ├── MotorClaimFiled                      └── HomeClaim
│   │   └── PropertyClaimFiled                       ├── FloodClaim
│   │       ├── FloodClaimFiled                      └── FireClaim
│   │       └── FireClaimFiled
│   ├── ClaimWithdrawn
│   ├── ClaimDecided ── ClaimApproved, ClaimDenied
│   └── ClaimReferred
├── PayoutEvent ── PayoutAuthorized, PayoutFailed
└── FraudSuspected
```

Domain relations between core concepts, each verified in `.glossmark/graph.jsonl`:

```
constrains    [('claim:AutoApprovalLimit', 'claim:ClaimAssessment'), ('claim:FilingWindow', 'claim:ClaimFiling'), ('claim:FraudReferralThreshold', 'claim:FraudScreening')]
reverses      [('claim:ClaimWithdrawal', 'claim:ClaimFiling')]
attaches-to   [('claim:LossEvidence', 'claim:Claim')]
escalates-to  [('claim:ClaimAssessment', 'claim:AdjusterReview'), ('claim:FraudScreening', 'claim:SpecialInvestigation')]
```

`escalates-to` is declared under `relations:` in the core file with `domain`, `range` and `doc`. Without that entry `gloss check` rejects it (`unknown relation "escalates-to" ... [GM200]`).

Three rules are **published** into the business view:

| Concept | Published as | Value | Bound to code by |
| --- | --- | --- | --- |
| `tide:FilingWindowRule` | `claim:FilingWindow` | `60 days` | `// @gloss publishes-value .FilingWindowRule scope=line` above `FILING_WINDOW_DAYS` in [FilingWindow.kt](services/claim-intake/src/main/kotlin/com/tidewater/claims/intake/domain/FilingWindow.kt) |
| `tide:AutoApprovalRule` | `claim:AutoApprovalLimit` | `5000 EUR` | `value-from: { path: .../settings.py, symbol: AUTO_APPROVE_LIMIT_EUR }` |
| `tide:FraudReferralPolicy` | `claim:FraudReferralThreshold` | `0.80` | `value-from: { path: .../Thresholds.kt, symbol: REFERRAL_SCORE_THRESHOLD }`, which now says `0.75`: the documented value-drift |

## Boundaries

| Manifest | Boundary | Declares |
| --- | --- | --- |
| [.gloss.yaml](.gloss.yaml) | `claimb:claims-events` (system) | `realizes: inherit`; `publishes` and `subscribes` **`claim:ClaimEvent`**; `produces` Claim, Assessment, Payout; `consumes` Claim, Policy, Payout. The schemas and docs sit directly under it |
| [services/claim-intake/.gloss.yaml](services/claim-intake/.gloss.yaml) | `claimb:claim-intake` | `realizes` filing, withdrawal, the filing window; `publishes` ClaimFiled, ClaimWithdrawn; `produces` Claim; `consumes` Policy, Claim; `holds` Claim |
| [services/assessment/.gloss.yaml](services/assessment/.gloss.yaml) | `claimb:assessment` | `realizes` assessment and the auto-approval limit; `subscribes` ClaimFiled, ClaimWithdrawn, FraudSuspected; `publishes` ClaimDecided, PayoutAuthorized; `produces` Assessment, Payout |
| [services/fraud-screening/.gloss.yaml](services/fraud-screening/.gloss.yaml) | `claimb:fraud-screening` | `realizes` screening and the referral threshold; `subscribes` ClaimFiled; `publishes` FraudSuspected |
| [services/payout-notifier/.gloss.yaml](services/payout-notifier/.gloss.yaml) | `claimb:payout-notifier` | `realizes` payout notification; `subscribes` PayoutAuthorized **and PayoutFailed**; `consumes` Payout |
| [contracts/.gloss.yaml](contracts/.gloss.yaml) | `claimb:contracts` | nothing: the contract documents events, it publishes none |
| [platform/.gloss.yaml](platform/.gloss.yaml) | `claimb:kafka-platform` | `realizes` the eight Kafka resources, derived from `provisions` on the Strimzi CRDs |
| [deploy/.gloss.yaml](deploy/.gloss.yaml) | `claimb:deploy` | `realizes` the four system-types, derived from `deploys` |

## What the tooling makes of it

Every finding below is intentional. CI compares the full output with [expected-drift.txt](expected-drift.txt) and [expected-check.txt](expected-check.txt), and fails on any dangling, rogue, presented-only, stale or proposed finding (`showcase/workspaces.tsv`). The workspace documents a violation and a value-drift, so it runs on the pinned binary, not the GlossMark Action.

| Derived from code | Declared | Result |
| --- | --- | --- |
| containers publish 11 event types (`MotorClaimFiled` … `FraudSuspected`) and subscribe to 7 | the system declares `publishes` and `subscribes` `claim:ClaimEvent` | **Consistent**: every derived event is an `is-a` descendant of `ClaimEvent`. The `event-flow` view folds the eleven edges into one lifted edge. Cut one `is-a` link and the system and two containers fail ([demo/taxonomy.sh](demo/taxonomy.sh)) |
| intake `produces` MotorClaim, FloodClaim, FireClaim; `represents` all five claim classes | system `produces` Claim; intake `produces`/`holds` Claim | Consistent through the claim taxonomy |
| `ReferralPublisher.refer` `publishes claim:ClaimReferred` on `claims.referrals.v1` | assessment declares `publishes [ClaimDecided, PayoutAuthorized]`; the AsyncAPI contract has no referrals channel | **Violation**: the referral feed was added in a hotfix and neither the manifest nor the contract followed. `gloss check` also warns GM503 on the marker (the one warning in `expected-check.txt`). The system is still consistent: `ClaimReferred` is a `ClaimEvent` |
| `consumer.go` handles `PayoutAuthorized`; `PayoutFailed` is a `TODO(PAY-412)` | payout-notifier declares `subscribes [PayoutAuthorized, PayoutFailed]` | **Gap**: the intent is declared, the code does not subscribe yet |
| `REFERRAL_SCORE_THRESHOLD = 0.75` in `Thresholds.kt` | `tide:FraudReferralPolicy` publishes `value: "0.80"` | **value-drift**: the threshold was tuned in code; the business still reads 0.80 ([demo/value-drift.sh](demo/value-drift.sh) resolves it two ways) |
| nothing implements `AdjusterReview`, `SpecialInvestigation` or `LossEvidence` | core concepts | **orphan**: the adjuster workbench, the SIU and the evidence upload service live outside this repository |
| `WithdrawalService` implements `tide:WithdrawalHandler` | no test verifies it or `claim:ClaimWithdrawal` | **untested**: the withdrawal path has no test |
| the three published rules | `criticality: high` on the core rules | Implementation concepts inherit `high`; `PayoutNotification` stays `medium` (see How it was adopted) |

```
$ gloss drift
✗ Violations (boundary exceeds its declared capability)
  claimb:assessment publishes claim:ClaimReferred but declares publishes {claim:ClaimDecided, claim:PayoutAuthorized}; rollup: publishes {claim:ClaimEvent} ⊄ declared  [services/assessment/assessment/referral.py:33]
≠ Published values drifted (the bound code changed, the value did not)
  published value drifted: tide:FraudReferralPolicy publishes "0.80", bound to services/fraud-screening/.../Thresholds.kt, which changed from "const val REFERRAL_SCORE_THRESHOLD = 0.80" to "const val REFERRAL_SCORE_THRESHOLD = 0.75"; update value: in the ontology, or confirm with gloss accept --value tide:FraudReferralPolicy  [...]
○ Gaps (declared, not implemented)
  claimb:payout-notifier declares subscribes claim:PayoutFailed but nothing under it subscribes to it: intended capability not implemented, or the declaration is wrong  [services/payout-notifier/.gloss.yaml:1]
· Orphan concepts (no artifacts)
  claim:AdjusterReview: orphan concept, no artifact links to it  [ontology/claim.gloss.yaml:117]
  claim:LossEvidence: orphan concept, no artifact links to it  [ontology/claim.gloss.yaml:31]
  claim:SpecialInvestigation: orphan concept, no artifact links to it  [ontology/claim.gloss.yaml:127]
△ Implemented but untested
  claim:ClaimWithdrawal is implemented but nothing tests or verifies it  [ontology/claim.gloss.yaml:102]
Concepts covered 71% (10/14 with an artifact and a verifier)   ...   Violations: 1   Gaps: 1   Stale: 0   Untested: 1
gloss drift: 3 failing findings (violation,value-drift,gap,dangling)
```

## The system-level rollup and the taxonomic lift

The root manifest makes one claim about the whole platform: it publishes and subscribes to claim events. No container declares `ClaimEvent`; each declares the families it owns, and its code marks the concrete events:

```kotlin
// @gloss publishes claim:MotorClaimFiled, claim:FloodClaimFiled, claim:FireClaimFiled conf=0.9
fun publishFiled(claim: Claim) = send(filedTopic, claim.id, claim.toFiledEvent())
```

`gloss drift` compares each boundary's derived set with its declaration under `is-a` subsumption, so the root, which derives 11 published and 7 subscribed event types, has no finding. The views show the same rollup. The `event-flow` view in [ontology/views.yaml](ontology/views.yaml) sets `lift: range-lcs`; `event-flow-flat` does not. Below are the edges of `gloss view --json` whose subject is a boundary, one line per edge:

```
== event-flow (lift: range-lcs, container zoom)
   claimb:assessment publishes claim:ClaimEvent lifted
   claimb:assessment subscribes claim:ClaimEvent lifted
   claimb:claim-intake publishes claim:ClaimLifecycleEvent lifted
   claimb:claims-events publishes claim:ClaimEvent lifted
   claimb:claims-events subscribes claim:ClaimEvent lifted
   claimb:fraud-screening publishes claim:FraudSuspected
   claimb:fraud-screening subscribes claim:ClaimFiled
   claimb:payout-notifier subscribes claim:PayoutEvent lifted
== event-flow-flat
   claimb:claim-intake publishes claim:ClaimFiled
   claimb:claim-intake publishes claim:ClaimWithdrawn
   claimb:claim-intake publishes claim:FireClaimFiled
   claimb:claim-intake publishes claim:FloodClaimFiled
   claimb:claim-intake publishes claim:MotorClaimFiled
   ...
```

The consistency depends on the taxonomy, not on the manifests. [demo/taxonomy.sh](demo/taxonomy.sh) cuts one link (`FloodClaimFiled` loses `is-a: PropertyClaimFiled`) in a temporary copy:

```
== 3. FloodClaimFiled cut out of the taxonomy (is-a: PropertyClaimFiled -> kind: event)
✗ Violations (boundary exceeds its declared capability)
  claimb:assessment publishes claim:ClaimReferred but declares ...                (the documented one)
  claimb:assessment subscribes claim:FloodClaimFiled but declares subscribes {claim:ClaimFiled, claim:ClaimWithdrawn, claim:FraudSuspected}; rollup: subscribes {...} ⊄ declared  [services/assessment/assessment/consumer.py:58]
  claimb:claim-intake publishes claim:FloodClaimFiled but declares publishes {claim:ClaimFiled, claim:ClaimWithdrawn}; rollup: publishes {...} ⊄ declared  [.../ClaimEventPublisher.kt:35]
  claimb:claims-events publishes claim:FloodClaimFiled but declares publishes {claim:ClaimEvent}; rollup: publishes {...} ⊄ declared  [.../ClaimEventPublisher.kt:35]
  claimb:claims-events subscribes claim:FloodClaimFiled but declares subscribes {claim:ClaimEvent}; rollup: subscribes {...} ⊄ declared  [services/assessment/assessment/consumer.py:58]
```

**What the ontology's `lift:` entries do in v0.1.0: nothing observable.** The core file declares `relations: { publishes: { lift: range-lcs } }` and the same for the other three flow relations, as GRAPH.md describes. Step 2 of the demo deletes those four lines and the drift output is byte-identical (`drift output identical`); the graph's publish edges are identical too. Subsumption is always on in the manifest comparison, every violation message prints its `rollup:` least common subsumer, and a view lifts when the *view* says `lift: range-lcs`. The entries stay in the file because they state the intent, and they are logged as an adoption finding.

Two other consequences of the rollup rules shaped the manifests:

- A process's intended flows are derived for every boundary that implements it (GRAPH.md rule 2). `ClaimFiling publishes [ClaimFiled]`, so intake must declare `ClaimFiled`, not only the three concrete subtypes.
- The same rule hides gaps. Adding `PayoutFailed` to `PayoutNotification.subscribes` in the core file makes the documented gap disappear, although no code subscribes to it. That is why the ontology states only what is built and the manifest states the plan.

## Avro schemas and the AsyncAPI contract

Avro schemas are JSON, which has no comments, so each event schema has a sidecar with one marker:

```
# schemas/FloodClaimFiled.avsc.gloss
# Sidecar for FloodClaimFiled.avsc (Avro is JSON, which has no comments). Scopes are JSON Pointers.
@gloss represents claim:FloodClaimFiled scope=range note="/fields" conf=0.9
```

The sidecar mechanism works for any extension: the artifact is `schemas/FloodClaimFiled.avsc`, and `gloss impact schemas/FloodClaimFiled.avsc` lists the intake publisher and the assessment consumer of the same event. **The JSON Pointer is not resolved in v0.1.0.** It is stored as the marker's note, the anchor is lines 1 to 2 (the sidecar's own line count), a pointer to nothing is accepted, and the fingerprint is a hash of the sidecar. Editing the schema never makes the link stale. The showcase therefore keeps one marker per sidecar; a second marker in the same sidecar would share the same artifact.

The AsyncAPI contract marks each channel with `documents` and `scope=block`, which anchors to the indented channel block:

```yaml
channels:
  # @gloss documents claim:ClaimFiled scope=block conf=0.85
  claimsFiled:
    address: claims.filed.v1
```

The five channel blocks anchor to lines 25-33, 35-38, 40-44, 46-50 and 52-55, and they did not go stale when the markers were accepted. The consumer-group files use the same scope on their `consumer:` block (`configures tide:AssessmentService scope=block`).

## Published values and the value-drift

The fraud team tuned the referral threshold from 0.80 to 0.75 in `Thresholds.kt`. The ontology still publishes 0.80, so drift reports **value-drift**. The finding survives rebuilds: the baseline line is kept in `.glossmark/ledger.jsonl` (an entry `value:tide:FraudReferralPolicy` with the old line), and `gloss build` twice in a row leaves the graph and ledger byte-identical, which `scripts/check-workspace.sh` checks. `gloss impact` marks the file HARD:

```
services/fraud-screening/src/main/kotlin/com/tidewater/claims/fraud/Thresholds.kt  [HARD, claimb:fraud-screening, criticality high]
  @gloss implements tide:FraudReferralPolicy  (line 6 Thresholds)
  claim:FraudReferralThreshold (constraint, core, high): published by tide:FraudReferralPolicy; constrains claim:FraudScreening
  → tide:FraudReferralPolicy is on the published seam: changes alter the business view (HARD)
```

[demo/value-drift.sh](demo/value-drift.sh) resolves it in a temporary git repository, both ways:

```
== A. value: "0.80" -> "0.75" in ontology/tide.gloss.yaml
0
Ontology impact — ws   base HEAD   gate HARD   criticality high
! published tide:FraudReferralPolicy value 0.80 → 0.75         ontology/tide.gloss.yaml:67   [HIGH, HARD: edit to ontology; business view affected: published concept]

== B. gloss accept --value tide:FraudReferralPolicy
confirm value of tide:FraudReferralPolicy: const val REFERRAL_SCORE_THRESHOLD = 0.75 is now the baseline for 0.80
gloss accept: 1 published value confirmed by agent:claude-code
0
    value: "0.80"
```

Option B clears the finding while the ontology still says 0.80 and the code says 0.75; `accept --value` does not compare them. Option A is the right fix.

## Why there is no dangling finding

A marker whose target does not exist is a `gloss check` error in v0.1.0, and the showcase contract requires `gloss check` to pass. [demo/dangling.sh](demo/dangling.sh) shows it in a copy, and shows the alternative, a proposed new concept:

```
== 1. // @gloss subscribes claim:ClaimReopened
services/payout-notifier/internal/consumer/consumer.go:56: error: dangling reference: claim:ClaimReopened does not exist [GM215]
gloss check: 1 error, 1 warning
(gloss check exit 1)
! Dangling references
  services/payout-notifier/internal/consumer/consumer.go:56 subscribes claim:ClaimReopened: concept does not exist (write claim:NEW:ClaimReopened with @gloss? to propose it)  [...]

== 2. // @gloss? subscribes claim:NEW:ClaimReopened conf=0.6
gloss check: 0 errors, 1 warning; 1 proposal, 1 rogue (run gloss status)
? Rogue concepts (decision requests)
  services/payout-notifier/internal/consumer/consumer.go:56 subscribes claim:NEW:ClaimReopened: rogue concept; becomes a decision request  [...]
```

The same GM215 error comes from a dangling target in a `@gloss?` proposal, a sidecar, a manifest and an ontology relation.

## Run it

```sh
export GLOSS=$PWD/../../.tools/bin/gloss      # from this directory, after scripts/install-gloss.sh
$GLOSS check && $GLOSS drift                   # the table above (drift exits 1: three findings fail by default)
demo/taxonomy.sh                               # the rollup, the no-op relation lift, and a cut is-a link
demo/value-drift.sh                            # resolve the value-drift by editing value: or by accept --value
demo/dangling.sh                               # why dangling cannot coexist with a passing gloss check
```

## How it was adopted

The code was written first with no GlossMark files. Then, in order:

1. `gloss init --dry-run` guessed `ce:`/`cei:`/`ceb:` and planned manifests for `contracts/` and `services/` only. `gloss init --core claim --impl tide --iri https://onto.tidewater.example/` wrote the scaffold. Its `.github/workflows/gloss.yml`, `.claude/settings.json` and `.mcp.json` were removed: this repository's root workflow drives CI. The `gloss` Makefile target it appended was kept.
2. The core and implementation tiers were written by hand. `services/.gloss.yaml` was replaced by one manifest per service, and `platform/` and `deploy/` got their own.
3. `gloss suggest --write` proposed 80 markers, all `implements`, `verifies` or `represents`, all in Kotlin, Python and Go. After review, 8 were kept as written, 22 retargeted and 50 deleted. It proposed no `publishes`, `subscribes`, `produces` or `consumes`, and nothing for Avro, AsyncAPI, Strimzi, Kubernetes, HOCON or `.properties` files. Those 53 markers were written by hand.
4. `gloss criticality suggest` proposed `high` for the three rules, their implementations, and three concepts "verified only by security tests". The review set the three core rules and `FraudScreening` to `high` and kept the implementation tier inheriting. It set `PayoutNotification` to `medium`: the "security test" was the Go test `TestPayoutAuthorizedNotifiesThePolicyholder`, flagged for the word "Authorized".
5. `gloss accept --policy`, then `gloss accept --all`. Accepting made 18 links stale at once: 7 `scope=file` links (F-ADOPT-8) and all 11 sidecar `scope=range` links, for the same reason. The stale ledger lines were dropped and `gloss build` re-recorded the markers as accepted. That workaround also deletes a value-drift baseline, which is stored as a stale ledger entry, so the threshold was changed only after it.
6. The value-drift was made last: `gloss build`, then the threshold changed in code, then `gloss build` again.

Every friction point is in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md). The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them yet.
