# Larkspur Clinics: appointment booking

**Shape:** a monorepo web product. **Shows:** pages and shells (`presents`, `hosts`), infrastructure, configuration and deployment links (`provisions`, `configures`, `deploys`), `holds` derived from `represents`, published values bound to code (`value-from`, `publishes-value`), criticality with a floor and `gloss criticality suggest`, a curated `views.yaml`, `realizes: inherit` and `allowed: [derived, ...]`.

Patients of Larkspur Clinics book and cancel outpatient appointments online. Reminders go out by SMS or email before each visit, and operations watch the no-show rate every Monday.

| Path | What | Stack |
| --- | --- | --- |
| `apps/web` | Patient site | Next.js 14, TypeScript, Playwright |
| `services/booking-api` | Slots, appointments, the cancellation rule | Go, chi, pgx |
| `services/reminders` | Reminder worker and the weekly no-show report | Python 3.12, boto3, psycopg |
| `db/migrations` | Schema | Postgres SQL |
| `infra/terraform` | RDS, SQS FIFO queue, EKS | Terraform (AWS) |
| `deploy/k8s` | Deployments, ConfigMaps, CronJob, Ingress | Kubernetes YAML |
| `.github/workflows` | Test and roll out | GitHub Actions |

The code is realistic but inert: it is never built here.

## The two tiers

**Core, `clinic:`** ([ontology/clinic.gloss.yaml](ontology/clinic.gloss.yaml)) is what a practice manager would recognise: `Patient`, `Practitioner`, `Clinic`, `Slot` and `Appointment` (entities), `Booking`, `Cancellation`, `AppointmentReminding` and `Waitlist` (processes), `Availability` (a capability), `NoShowRate` (a measure), and two rules, `CancellationWindow` and `ReminderLeadTime` (constraints). `Cancellation reverses Booking`; each constraint `constrains` the process it governs.

**Implementation, `lark:`** ([ontology/lark.gloss.yaml](ontology/lark.gloss.yaml)) is what an engineer would name: three deployable `system-type`s (`BookingApiService`, `ReminderService`, `PatientSite`), the handlers that realize the core processes, three `internal` resources (`BookingDatabase`, `ReminderQueue`, `BookingCluster`), and five page concepts that `presents` a core concept instead of realizing it. `ReminderDispatch` is `part-of` `ReminderPlanner`.

Two implementation values are **published** into the business view:

| Concept | Published as | Value | Bound to code by |
| --- | --- | --- | --- |
| `lark:CancellationPolicy` | `clinic:CancellationWindow` | `24h` | `value-from: { path: .../cancellation.go, symbol: CancellationWindow }` in the ontology |
| `lark:LeadTimeSetting` | `clinic:ReminderLeadTime` | `48h` | `# @gloss publishes-value .LeadTimeSetting scope=line` above `REMINDER_LEAD_HOURS` in [settings.py](services/reminders/reminders/settings.py) |

Change either constant without changing `value:` and `gloss drift` reports **value-drift**; `gloss diff` makes it HARD. [demo/gates.sh](demo/gates.sh) shows it.

## Boundaries

| Manifest | Boundary | Declares |
| --- | --- | --- |
| [.gloss.yaml](.gloss.yaml) | `clinicb:clinic-booking` (system) | `realizes: inherit`: the union of what its containers declare |
| [apps/web/.gloss.yaml](apps/web/.gloss.yaml) | `clinicb:web` | `presents` seven core concepts, `hosts` the five pages, `realizes` the page concepts and the shell |
| [services/booking-api/.gloss.yaml](services/booking-api/.gloss.yaml) | `clinicb:booking-api` | `realizes` Booking, Cancellation, Availability and the cancellation policy; `holds` four entities; `criticality: high` |
| [services/reminders/.gloss.yaml](services/reminders/.gloss.yaml) | `clinicb:reminders` | `realizes` reminding and the no-show rate; `allowed: [derived, clinic:Appointment]` because the worker consumes appointments it does not realize |
| [db/.gloss.yaml](db/.gloss.yaml) | `clinicb:db` | `holds` five entities; `criticality: high` with `criticality-floor: true` |
| [infra/.gloss.yaml](infra/.gloss.yaml) | `clinicb:infra` | `realizes` the three resources, derived from `provisions` |
| [deploy/.gloss.yaml](deploy/.gloss.yaml) | `clinicb:deploy` | `realizes` the three system-types, derived from `deploys` |

## What the tooling makes of it

Every finding below is intentional. CI compares the full output with [expected-drift.txt](expected-drift.txt) and [expected-check.txt](expected-check.txt), and fails on any violation, gap, value-drift, dangling, rogue, stale or proposed finding (`showcase/workspaces.tsv`).

| Derived from code | Declared | Result |
| --- | --- | --- |
| `booking-api` implements BookingHandler, CancellationHandler, SlotSearch, CancellationPolicy | manifest realizes Booking, Cancellation, Availability, CancellationPolicy | Consistent: each handler lifts through `realizes` to its core process |
| models and tables `represents` Patient, Appointment, Practitioner, Slot, Clinic | `booking-api` and `db` declare `holds` | Consistent: `holds` is derived from `represents` on entities |
| `infra` `provisions` three internal resources; `deploy` `deploys` and `configures` three system-types | `realizes` the same | Consistent: `provisions`, `deploys` and `configures` lift to `realizes` on resources and system-types |
| the root realizes everything its containers realize | `realizes: inherit` | Consistent, with no list repeated at the root |
| `WaitlistPage` presents `clinic:Waitlist`; nothing implements it | `clinic:Waitlist` in core | **presented-only** and **orphan**: the page ships before the backend; a surface with no mechanism behind it |
| `NoShowDashboard`, `PractitionerDirectory`, `WaitlistPage`, `PatientSite` implemented | no test verifies them | **untested**: pages and the shell have no component tests yet |
| `SlotSearch` implements `clinic:Availability` | no test verifies either | **untested**: the availability search has no unit test; the real gap in this codebase |
| web pages `presents` Booking and Appointment, which are `high` | `presents` carries no criticality | The pages stay unclassified; only the mechanisms are `high` |
| unmarked `0006_roles.sql` grants access to patient tables | `db` has `criticality-floor: true` | `gloss impact` reports it `high` through the floor; the SQLite export omits it, because an unmarked file is not an artifact (see `lab/ADOPTION-LOG.md`, C16) |

```
$ gloss drift
· Orphan concepts (no artifacts)
  clinic:Waitlist: orphan concept, no artifact links to it
◇ Presented but not implemented (a surface with no mechanism)
  clinic:Waitlist is presented (lark:WaitlistPage) but nothing implements it
△ Implemented but untested
  lark:NoShowDashboard, lark:PatientSite, lark:PractitionerDirectory, lark:SlotSearch, lark:WaitlistPage
Concepts covered 69% (11/16 with an artifact and a verifier)   Files 54% (47/87)   Violations: 0   Gaps: 0   Stale: 0
```

## Criticality

Declared where the business sees it: `Patient` (PII), `Appointment` and `Booking` are `high`. `gloss criticality suggest` proposed `high` for both constraints and for the two implementation concepts that publish them. The review kept `CancellationWindow` at `high`, lowered `ReminderLeadTime` to `medium` with a comment saying why, and dropped the implementation lines because they inherit from what they realize. `gloss criticality suggest` still proposes `lark:LeadTimeSetting → high` on every run, because it inherits `medium` and the tool only skips concepts at `high` or above; that is logged in the lab.

The `db` boundary sets `criticality-floor: true`, so every migration is at least `high` in `gloss impact`, marked or not, and every marked one is `high` in the SQLite export.

## Views

[ontology/views.yaml](ontology/views.yaml) keeps the generated `business` and `engineering` presets and adds two curated views: `patient-data` (where PII lives, which code shapes it, what provisions its storage) and `published-values` (the two published values and the code each is bound to). A curated view names concepts, so the viewer opens it with every box open.

## Gates

[demo/gates.sh](demo/gates.sh) copies this workspace to a temporary git repository, commits it, makes one change of each class, and runs `gloss diff --base HEAD`:

```
Ontology impact — ws (clinicb:booking-api)   base HEAD   gate HARD   criticality high
≠ published value of lark:CancellationPolicy drifted: ... changed from "const CancellationWindow = 24 * time.Hour" to "... 12 * time.Hour" while value: stays 24h   [HIGH, HARD: published value drifted]
? implements lark:PractitionerDirectory   services/booking-api/internal/httpapi/slots.go:handlers.listPractitioners   [agent, conf 0.50, HARD: conf 0.50 below threshold 0.70]
? implements lark:SlotSearch              services/booking-api/internal/httpapi/slots.go:handlers.listSlots           [agent, conf 0.88, SOFT: auto-accept eligible]
~ implements lark:SlotSearch anchor signature changed   services/booking-api/internal/booking/availability.go:Service.FindOpenSlots   [AUTO]
```

## Run it

```sh
export GLOSS=$PWD/../../.tools/bin/gloss      # from this directory, after scripts/install-gloss.sh
$GLOSS check && $GLOSS drift                   # the table above
demo/gates.sh                                  # AUTO, SOFT and HARD in one diff
demo/tour.sh                                   # version, check --explain, coverage, criticality suggest, impact, view, export, doctor
```

## How it was adopted

The code was written first with no GlossMark files. Then, in order: `gloss init --dry-run` (guessed `cb:`/`cbi:`; overridden with `--core clinic --impl lark`), `gloss init`, the core and implementation tiers by hand, manifests moved from the grouping directories `apps/` and `services/` to the three deployables, `gloss suggest --write` (126 proposals, 28 kept after review, most of those retargeted), hand-written markers for everything `suggest` cannot see (pages, shells, infrastructure, config, deploys, docs, behavioural tests), `gloss criticality suggest`, `gloss accept --policy` then `gloss accept --all`. Every friction point is in [lab/ADOPTION-LOG.md](../../lab/ADOPTION-LOG.md). The links were written and accepted by an agent (`agent:claude-code`); no human has reviewed them yet.

`gloss init` also wrote `.github/workflows/gloss.yml`, `.claude/settings.json` and `.mcp.json` here. They were removed: GitHub never runs a workflow in a subdirectory, so this repository's root workflow drives CI.
