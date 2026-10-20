# Pepper Row: ordering and kitchen display, maintained by agents

**Shape:** an agent-heavy repository. **Shows:** `instructs` on every agent file, three subagents with `may-modify` remits written as globs, the HARD gate on an out-of-remit link, `@gloss?` proposals on both sides of an explicit `soft-conf-threshold` with the `conf`, `note` and `id` keys, a rogue `ns:NEW:` concept, a `proposed: true` concept from `gloss propose --from-new`, every review state in the ledger (proposed, accepted, rejected, stale, and removed in a demo) with one actor per subagent, the kept hook files, `gloss agents --write AGENTS.md`, `gloss context`, `gloss impact`, and the MCP server driven over stdio.

Pepper Row is a group of three restaurants: Canal Street, Harbour and Market Hall. Servers open an order for a table, record the allergens the guests declare, and fire it. The API splits a fired order into one ticket per kitchen station and pushes each to that station's screen. When the table is served, the API hands the bill to the card processor and settles the order from the processor's webhook. One rule matters more than the rest: no dish containing, or possibly containing, a declared allergen is fired without a member of staff acknowledging it, and every station that cooks it sees an alert.

The repository is maintained mostly by coding agents, and one person reviews every pull request.

| Path | What | Stack |
| --- | --- | --- |
| `api/` | Menu, orders, the allergen check, ticket routing, payment handoff | Python 3.12, FastAPI, asyncpg, pytest |
| `kds/` | Kitchen display: one screen per station, the allergen banner | TypeScript, Vite, Vitest |
| `db/migrations/` | Schema, append only | Postgres SQL |
| `docs/` | The allergen policy and the order lifecycle | Markdown |
| `AGENTS.md`, `CLAUDE.md` | The shared agent brief and the Claude Code additions | Markdown |
| `.claude/agents/` | Three subagents: `menu-curator`, `order-flow-engineer`, `allergen-auditor` | Claude Code agent files |
| `.claude/skills/` | `add-menu-item`, `allergen-audit`, and `adopt-glossmark` (installed by `gloss hook install --skill`) | Claude Code skills |
| `.claude/settings.json`, `.mcp.json` | The SessionStart hook and the MCP server, as `gloss init` wrote them | JSON |

The code is realistic but inert: it is never built here.

## The agent layer

Every agent file carries `instructs`. Each subagent also carries a `may-modify` remit. A remit is a list of concept globs: a link that agent writes to a concept outside it is HARD in the gate, whatever its confidence.

| File | `instructs` | `may-modify` |
| --- | --- | --- |
| [AGENTS.md](AGENTS.md) | `dineb:kitchen-agents` (the system boundary) | |
| [CLAUDE.md](CLAUDE.md) | `dineb:kitchen-agents` | |
| [.claude/agents/menu-curator.md](.claude/agents/menu-curator.md) | `pepper:MenuCatalog` | `dine:Menu*, pepper:Menu*` |
| [.claude/agents/order-flow-engineer.md](.claude/agents/order-flow-engineer.md) | `pepper:OrderFlow, pepper:TicketRouter, pepper:PaymentHandoff, pepper:KitchenDisplay` | `dine:Order*, dine:KitchenTicket, dine:Checkout, dine:Payment, pepper:Order*, pepper:Ticket*, pepper:Payment*, pepper:KitchenDisplay` |
| [.claude/agents/allergen-auditor.md](.claude/agents/allergen-auditor.md) | `dine:AllergenRule` | `dine:Allergen*, pepper:Allergen*` |
| [.claude/skills/add-menu-item/SKILL.md](.claude/skills/add-menu-item/SKILL.md) | `pepper:MenuCatalog` | |
| [.claude/skills/allergen-audit/SKILL.md](.claude/skills/allergen-audit/SKILL.md) | `dine:AllergenRule` | |

Claude Code reads YAML frontmatter only on line 1 of an agent or skill file, so the markers sit right after the frontmatter with `scope=file`. AGENTS.md is the exception: its marker sits above the top heading with no scope, so it anchors to that heading. `gloss agents --write AGENTS.md` rewrites the generated vocabulary block between `<!-- gloss:begin -->` and `<!-- gloss:end -->`. Tried with `scope=file`, the link went stale as soon as a changed `doc:` changed the generated table (F-ADOPT-8, C20). The heading anchor does not go stale.

The installed `adopt-glossmark` skill carries GlossMark's own marker, `instructs gm:Onboarding`, which does not resolve here: `gloss check` fails with GM210 and drift reports it as dangling. It is vendored, so [glossmark.yaml](glossmark.yaml) excludes it.

## The two tiers

**Core, `dine:`** ([ontology/dine.gloss.yaml](ontology/dine.gloss.yaml)) is what a head chef or a floor manager would name. Its entities are `Location`, `Menu`, `MenuItem` (part of `Menu`), `Allergen`, `Order`, `KitchenTicket`, `Station` and `Payment`. Its processes are `MenuPublishing`, `Ordering`, `KitchenFulfilment` and `Checkout`. Its one rule is `AllergenRule`, a constraint that `constrains` `Ordering` and `KitchenFulfilment` and is declared **`criticality: critical`**. `Allergen` is `high` because the declared list is a legal record. Aliases carry the kitchen's words: `chit` and `docket` for a ticket, `expo` and `bumping` for fulfilment, `allergy check` for the rule.

**Implementation, `pepper:`** ([ontology/pepper.gloss.yaml](ontology/pepper.gloss.yaml)) is what an engineer would name. It has two deployables, `OrderingApi` and `KitchenDisplay`, both `system-type`. The API mechanisms are `MenuCatalog`, `OrderFlow`, `AllergenGuard`, `TicketRouter` and `PaymentHandoff`. The display has `TicketStore`, which is `part-of` `KitchenDisplay`, and two screens, `TicketBoard` and `AllergenBanner`, that `presents` a core concept instead of realizing it. `MenuAvailability` is a proposed concept, described below.

## Boundaries

| Manifest | Boundary | Declares |
| --- | --- | --- |
| [.gloss.yaml](.gloss.yaml) | `dineb:kitchen-agents` (system) | `realizes: inherit`. The agent layer and `docs/` sit here: `instructs`, `may-modify` and `documents` do not lift, so they add nothing to compare. |
| [api/.gloss.yaml](api/.gloss.yaml) | `dineb:api` | `realizes` the six API mechanisms; `holds` six entities. Inherits `critical` from `AllergenRule` |
| [db/.gloss.yaml](db/.gloss.yaml) | `dineb:db` | `holds` seven entities |
| [kds/.gloss.yaml](kds/.gloss.yaml) | `dineb:kds` | `realizes`, `hosts` and `presents` the screens, and a written `allowed:` list narrower than the derived set: the display may not link to anything in the API |

The API boundary is `critical`, but only links to a critical concept are HARD by criticality. GOVERNANCE.md says a boundary's level reaches its files only with `criticality-floor: true`, and `gloss diff` agrees: a link to `pepper:MenuCatalog` in `api/` is SOFT.

## What the tooling makes of it

Every finding below is intentional. CI compares the full output with [expected-drift.txt](expected-drift.txt) and [expected-check.txt](expected-check.txt). It fails on any violation, gap, value-drift, dangling, orphan or presented-only finding (`showcase/workspaces.tsv`). Rogue, proposed and stale are what this example documents, and they are not in the Action's hard-coded fail list, so the Action runs here too.

| Derived from code | Declared | Result |
| --- | --- | --- |
| API services implement the six mechanisms; models and tables `represents` seven entities | `api` realizes and holds them; `db` holds them | Consistent |
| the display implements `KitchenDisplay`, `TicketStore`, `TicketBoard`, `AllergenBanner` | `kds` realizes, hosts and presents them inside a written `allowed:` list | Consistent |
| `implements pepper:NEW:SplitBill` on `split_evenly`, written by `agent:order-flow-engineer` | nothing | **rogue**: a decision request for the namespace owner, committed as is |
| `pepper:MenuAvailability`, lifted by `gloss propose --from-new` from the menu-curator's `NEW:` marker | `proposed: true` in the ontology | **proposed**: HARD until `gloss accept --concept` |
| `route_ticket` gained an `open_stations` parameter after its link was accepted | the ledger holds the old fingerprint | **stale** |
| `KitchenDisplay` and `TicketBoard` are implemented | no test verifies them | **untested**: the display shell and the board have no component tests |
| eight `@gloss?` links written by the subagents | awaiting review | Counted under "Proposed links" in the summary line, and listed with a gate by `gloss status`; none is a finding |

```
$ gloss drift
? Rogue concepts (decision requests)
  api/ordering/services/payment_handoff.py:65 implements pepper:NEW:SplitBill: rogue concept; becomes a decision request
? Proposed concepts (awaiting acceptance)
  pepper:MenuAvailability is a proposed process by agent:menu-curator; accept with gloss accept --concept pepper:MenuAvailability
~ Stale links (anchor changed)
  api/ordering/services/ticket_router.py: implements .TicketRouter is stale, the anchored signature changed since it was accepted; re-confirm with gloss accept m-5f5d5197a5
△ Implemented but untested
  pepper:KitchenDisplay is implemented but nothing tests or verifies it (nor dine:KitchenFulfilment, which it realizes)
  pepper:TicketBoard is implemented but nothing tests or verifies it
Decision requests
  propose pepper:SplitBill (implements at api/ordering/services/payment_handoff.py:65)  — guests ask to split the bill; Checkout assumes one payment per order
  accept or reject proposed pepper:MenuAvailability (ontology/pepper.gloss.yaml:53)
Concepts covered 80% (8/10 with an artifact and a verifier)   Files ...   Orphans: 0   Rogue: 1   Violations: 0   Gaps: 0   Stale: 1   Untested: 2   Proposed links: 8   Proposed concepts: 1
```

`re-confirm with gloss accept m-5f5d5197a5` does not work in v0.1.0. `gloss accept` refuses a stale link (F-ADOPT-8, C14).

## Who wrote what: the ledger

[.glossmark/ledger.jsonl](.glossmark/ledger.jsonl) records the actor that first built each marker. The adoption pass ran as `agent:claude-code`. Each subagent's later links were built with its own actor (`GLOSS_ACTOR=agent:menu-curator gloss build`), and `agent:claude-code` did the review. No human has reviewed anything yet.

| Actor | accepted | proposed | rejected | stale | removed |
| --- | --: | --: | --: | --: | --: |
| `agent:claude-code` | 36 | | | 1 | |
| `agent:menu-curator` | 1 | 4 | 1 | | 1 |
| `agent:order-flow-engineer` | 6 | 3 | | | |
| `agent:allergen-auditor` | 3 | 2 | | | |

- The **rejected** row is the menu-curator's `implements .MenuCatalog` on `MenuRepository`. It was rejected with `gloss reject menu-repo-helper --reason "a repository is a helper..."` and no `--remove`, so the `@gloss?` line stays in the source. With `--remove` the row would read `removed`, not `rejected`. The reason is not in the ledger: when a marker has `note=`, the ledger's one `rationale` field keeps the note and drops the reason.
- The menu-curator's **removed** row is a side effect of `propose --from-new`. Rewriting `pepper:NEW:MenuAvailability` to `pepper:MenuAvailability` changed the marker's derived id, so the old id is recorded as removed and the rewritten marker starts a new row. A deliberate removal is in [demo/review.sh](demo/review.sh).
- The concept itself has a row too, `concept:pepper:MenuAvailability`, with status `proposed`.

### Proposals, marker keys and the threshold

[glossmark.yaml](glossmark.yaml) sets `soft-conf-threshold: 0.7` explicitly. Every committed proposal carries the three keys an agent may add besides `scope`:

- `conf=` is the agent's confidence. At or above the threshold, a valid link inside the allowed set and the agent's remit is SOFT; below it, HARD.
- `note="..."` is the rationale. The ledger stores it as `rationale`, and `gloss drift` prints it next to a decision request.
- `id=` is a stable marker id. It becomes the ledger's `marker_id` and the handle for `gloss accept` and `gloss reject`. Without it the id is derived from the marker and changes when the marker does, as the `propose --from-new` row above shows.

```
$ gloss status
proposed (9)
  allergen-may-contain-test  api/tests/test_allergen_guard.py  verifies dine:AllergenRule conf=0.92  by agent:allergen-auditor  [SOFT]
  allergen-station-alert-test  api/tests/test_ticket_router.py  verifies .AllergenGuard conf=0.60  by agent:allergen-auditor  [HARD]
  concept:pepper:MenuAvailability  ontology/pepper.gloss.yaml  concept pepper:MenuAvailability  by agent:menu-curator
  m-54dba03d39  api/ordering/services/menu_catalog.py  implements pepper:MenuAvailability  by agent:menu-curator  [HARD]
  m-dbe14a0c97  api/ordering/services/payment_handoff.py  implements pepper:NEW:SplitBill  by agent:order-flow-engineer  [HARD]
  menu-get-route  api/ordering/routers/menu.py  implements .MenuCatalog conf=0.85  by agent:menu-curator  [SOFT]
  menu-unknown-section-test  api/tests/test_menu_catalog.py  verifies .MenuCatalog conf=0.50  by agent:menu-curator  [HARD]
  order-fire-refusal-test  api/tests/test_order_flow.py  verifies .OrderFlow conf=0.75  by agent:order-flow-engineer  [SOFT]
  ticket-bump-route  api/ordering/routers/tickets.py  implements .TicketRouter conf=0.45  by agent:order-flow-engineer  [HARD]
stale (1)
  m-5f5d5197a5  api/ordering/services/ticket_router.py  implements .TicketRouter conf=0.82  by agent:claude-code  [SOFT]
rejected (1)
  menu-repo-helper  api/ordering/repositories/menu_repo.py  implements .MenuCatalog conf=0.62  by agent:menu-curator  [HARD]
```

| Proposal | conf | `status` says | Why |
| --- | --: | --- | --- |
| `menu-get-route` | 0.85 | SOFT | above 0.7, inside the menu-curator's remit |
| `order-fire-refusal-test` | 0.75 | SOFT | above 0.7, inside the order-flow-engineer's remit |
| `menu-unknown-section-test` | 0.50 | HARD | below 0.7 |
| `ticket-bump-route` | 0.45 | HARD | below 0.7 |
| `allergen-station-alert-test` | 0.60 | HARD | below 0.7 |
| `allergen-may-contain-test` | 0.92 | **SOFT, but HARD in `gloss diff`** | targets the `critical` rule; see below |
| the two `pepper:` concept links | none | HARD | a new or proposed concept |

**`gloss status` and `gloss diff` disagree on critical links.** The default policy makes any link to a `critical` concept HARD, and `gloss diff` applies it. `gloss status`, `gloss accept --policy` and the MCP `propose_link` and `impact_of` tools do not: they classify the same link SOFT, so `accept --policy` would auto-accept it. [demo/remit.sh](demo/remit.sh) shows both views of one link:

```
? verifies dine:AllergenRule   api/tests/test_allergen_guard.py:test_no_declaration_means_no_conflict   [CRITICAL, agent, conf 0.95, HARD: existing concept, valid, inside allowed; criticality critical: dine:AllergenRule]

$ gloss status | grep allergen-no-declaration-test
  allergen-no-declaration-test  api/tests/test_allergen_guard.py  verifies dine:AllergenRule conf=0.95  by agent:allergen-auditor  [SOFT]
```

## Remits: the out-of-remit HARD gate

[demo/remit.sh](demo/remit.sh) copies this workspace to a temporary git repository and commits it. Then the menu-curator (`GLOSS_ACTOR=agent:menu-curator`, which matches `.claude/agents/menu-curator.md`) makes one change inside its remit and one outside it, at nearly the same confidence. For contrast, the allergen-auditor proposes a link to the critical rule from inside its own remit.

```
$ GLOSS_ACTOR=agent:menu-curator gloss context --dir api --budget 0   # (remit lines)
Boundary: dineb:api (container); `.Name` = `pepper:Name`; realizes pepper:OrderingApi, pepper:MenuCatalog, pepper:OrderFlow, pepper:AllergenGuard, pepper:TicketRouter, pepper:PaymentHandoff; criticality critical (inherited from dine:AllergenRule)
Your remit as agent:menu-curator: you may modify dine:Menu*, pepper:Menu* (.claude/agents/menu-curator.md). Links outside it are HARD-gated.

$ gloss diff --base HEAD
Ontology impact — ws (dineb:api)   base HEAD   gate HARD   criticality critical
? verifies dine:AllergenRule       api/tests/test_allergen_guard.py:test_no_declaration_means_no_conflict   [CRITICAL, agent, conf 0.95, HARD: existing concept, valid, inside allowed; criticality critical: dine:AllergenRule]
? implements pepper:OrderFlow      api/ordering/services/order_flow.py:unavailable_lines          [agent, conf 0.90, HARD: outside menu-curator may-modify remit]
? implements pepper:MenuCatalog    api/ordering/services/menu_catalog.py:group_into_sections      [agent, conf 0.88, SOFT: auto-accept eligible]
~ stale implements .TicketRouter   api/ordering/services/ticket_router.py                         [AUTO]
...
Criticality touched: dine:AllergenRule critical (declared)
```

Without an agent actor the briefing lists every remit. With one, it shows only that agent's remit ([demo/tour.sh](demo/tour.sh)):

```
$ gloss context --dir kds
Agent remits: .claude/agents/allergen-auditor.md may modify dine:Allergen*, pepper:Allergen*; .claude/agents/menu-curator.md may modify dine:Menu*, pepper:Menu*; .claude/agents/order-flow-engineer.md may modify dine:Order*, dine:KitchenTicket, dine:Checkout, dine:Payment, pepper:Order*, pepper:Ticket*, pepper:Payment*, pepper:KitchenDisplay
$ GLOSS_ACTOR=agent:allergen-auditor gloss context --dir kds
Your remit as agent:allergen-auditor: you may modify dine:Allergen*, pepper:Allergen* (.claude/agents/allergen-auditor.md). Links outside it are HARD-gated.
```

A change to an agent file's own `instructs` or `may-modify` line is HARD too, with the reason `agent remit or instructions changed`. ADVANCED.md's list of HARD changes does not mention it.

## The review lifecycle

[demo/review.sh](demo/review.sh) accepts the proposed concept, turns the rogue into a proposed concept and rejects it, and withdraws one proposal. It runs on a temporary git repository.

```
$ gloss accept --concept pepper:MenuAvailability
gloss: pepper:MenuAvailability: add realizes: <core concept> or internal: true before accepting
                                   # the reviewer adds realizes: dine:MenuPublishing
$ gloss accept --concept pepper:MenuAvailability
gloss accept: 1 concept accepted by agent:claude-code

$ gloss propose --from-new --doc "Splitting one bill into several payments at the table."
gloss propose: pepper:SplitBill (process) proposed in ontology/pepper.gloss.yaml; 1 marker(s) rewritten
$ gloss reject --concept --reason "Tillpoint splits the bill at the terminal; one payment per order stays" --remove pepper:SplitBill
reject concept pepper:SplitBill — Tillpoint splits the bill at the terminal; one payment per order stays
                                   # the entry is deleted and the marker goes back to pepper:NEW:SplitBill
$ jq ... .glossmark/ledger.jsonl   # after deleting the ticket-bump-route marker line and gloss build
{"marker_id":"concept:pepper:MenuAvailability","status":"accepted","actor":"agent:menu-curator","reviewed_by":"agent:claude-code",...}
{"marker_id":"concept:pepper:SplitBill","status":"removed","actor":"agent:order-flow-engineer","reviewed_by":"agent:claude-code","rationale":"Tillpoint splits the bill at the terminal; one payment per order stays"}
{"marker_id":"ticket-bump-route","status":"removed","actor":"agent:order-flow-engineer","reviewed_by":null,"rationale":"bumping may belong to the display, not the router"}

$ gloss diff --base HEAD --fail-on none
! pepper:MenuAvailability realizes dine:MenuPublishing added   ontology/pepper.gloss.yaml:53                 [HARD: edit to ontology]
- implements pepper:TicketRouter removed                       api/ordering/routers/tickets.py:bump_ticket   [SOFT]
! namespace pepper: changes require a MINOR bump but version went 0.1.0 → 0.1.0 (none)   ontology/pepper.gloss.yaml   [SOFT]
~ stale implements .TicketRouter                               api/ordering/services/ticket_router.py        [AUTO]
+ concept pepper:MenuAvailability accepted                     ontology/pepper.gloss.yaml:53                 [AUTO]

$ gloss export --prov prov.jsonld && jq ...
{"@id":"urn:gloss:activity:menu-repo-helper","@type":"prov:Activity","prov:wasAssociatedWith":"urn:gloss:actor:agent:menu-curator","prov:generated":"urn:gloss:marker:menu-repo-helper","prov:startedAtTime":"2026-10-20T03:03:51Z","gm:status":"rejected","gm:reviewedBy":"agent:claude-code"}
```

Three things to know from this run:

- `accept --concept` wants `realizes:` or `internal: true`. `gloss check` (GM320) accepts the `part-of: MenuCatalog` the committed entry carries.
- The QUICKSTART writes `gloss reject --concept pepper:X --reason "..." --remove`. With the flags after the CURIE they are not parsed, and the command fails with `--reason is required`. Put the flags first.
- `--remove` records `removed`, not `rejected`, for a concept as for a link.

## What an agent sees

**At session start.** `gloss init` and `gloss hook install --skill` wrote [.claude/settings.json](.claude/settings.json) and [.mcp.json](.mcp.json), kept here as written:

```
{"command":"GLOSS_ACTOR=agent:claude-code gloss context --dir \"$PWD\" --changed --budget 2000 2>/dev/null || true","type":"command"}
{"args":["mcp"],"command":"gloss","env":{"GLOSS_ACTOR":"agent:claude-code"}}
```

Both, and the `gloss` target `init` appended to the [Makefile](Makefile), call a bare `gloss` from `PATH`, which on the authoring machine is an unrelated program (C4). The hook sets `GLOSS_ACTOR` for its own `gloss context` call only. The variable is not exported to the session, so a later `gloss build` that an agent runs from its shell attributes new markers by the fallback chain, not to the agent. `gloss doctor` in a plain shell says: `GLOSS_ACTOR: unset; new markers by a human are attributed to human:mckalvan`. The MCP server has one actor for its lifetime, so every subagent in a session shares it. The per-subagent actors in this ledger were set by hand on each `gloss build`.

The briefing a session opens with starts with what the uncommitted changes touch. In [demo/remit.sh](demo/remit.sh), after the menu-curator's change:

```
$ gloss context --dir api --changed
## You are touching
.glossmark/graph.jsonl  [AUTO, dineb:kitchen-agents]
  → no @gloss links in this file; add one so the change is attributable to a concept
.glossmark/ledger.jsonl  [AUTO, dineb:kitchen-agents]
  → no @gloss links in this file; add one so the change is attributable to a concept
api/ordering/services/menu_catalog.py  [HARD, dineb:api]
  @gloss implements pepper:MenuCatalog  (line 12 MenuCatalog)
  @gloss? implements pepper:MenuAvailability  (line 21 mark_unavailable)
  @gloss? implements pepper:MenuCatalog  (line 29 group_into_sections)
  ...
api/ordering/services/order_flow.py  [SOFT, dineb:api]
  @gloss implements pepper:OrderFlow  (line 23 OrderFlow)
  @gloss? implements pepper:OrderFlow  (line 85 unavailable_lines)
  ...
```

Two things in it mislead. It advises adding a `@gloss` link to the tool's own graph and ledger files. And it labels `order_flow.py` SOFT, although `gloss diff` on the same tree makes the link in it HARD for the remit. `gloss impact --base HEAD` prints the same SOFT label above its own HARD classification.

**Over MCP.** [demo/mcp.py](demo/mcp.py) starts `gloss mcp` on a temporary copy and speaks newline-delimited JSON-RPC to it, as a harness does. The first session runs as the menu-curator. Responses are trimmed; `demo/mcp.py --raw` prints them whole.

```
### gloss mcp with GLOSS_ACTOR=agent:menu-curator
→ initialize
← serverInfo {"name": "glossmark", "version": "0.1.0"} | instructions: GlossMark serves the repository's code ontology. Call concepts_for_path before writing code in a directory, search_concepts to find the right concept, propose_l...
→ tools/list
← lookup_concept, search_concepts, concepts_for_path, propose_link, impact_of, propose_concept, context, drift

→ tools/call search_concepts {"query": "chit"}
← [{"curie": "dine:KitchenTicket", "kind": "entity", "aliases": ["chit", "docket", "ticket"], "artifacts": 4, "score": 95, "matched": "alias:chit"}]

→ tools/call search_concepts {"query": "allergy check", "limit": 2}
← [{"curie": "dine:AllergenRule", "kind": "constraint", "aliases": ["allergy check", "allergen check"], "artifacts": 4, "score": 95, "matched": "alias:allergy check"}, {"curie": "dine:Allergen", "kind": "entity", "aliases": ["allergy"], "artifacts": 3, "score": 45, "matched": "alias:allergy"}]

→ tools/call concepts_for_path {"path": "api/ordering/services/allergen_guard.py"}
← {"boundary": "dineb:api", "realizes": ["pepper:OrderingApi", "pepper:MenuCatalog", "pepper:OrderFlow", "pepper:AllergenGuard", "pepper:TicketRouter", "pepper:PaymentHandoff"], "allowed": ["pepper:*", "dine:Allergen", "dine:AllergenRule", "dine:Checkout", "..."],
   "links": [{"line": 45, "marker_id": "m-6c2289a737", "proposed": false, "relation": "implements", "symbol": "enforce_allergen_rule", "target": "pepper:AllergenGuard"}]}

→ tools/call propose_link {"path": "api/ordering/services/menu_catalog.py", "relation": "implements", "target": ".MenuCatalog", "conf": 0.88}
← {..., "gate": "SOFT", "proposals": [{"gate": "SOFT", "marker": "# @gloss? implements .MenuCatalog conf=0.88", "reasons": ["existing concept, valid, inside allowed"], ...}]}

→ tools/call propose_link {"path": "api/ordering/services/order_flow.py", "relation": "implements", "target": ".OrderFlow", "conf": 0.9}
← {..., "gate": "HARD", "proposals": [{"gate": "HARD", "marker": "# @gloss? implements .OrderFlow conf=0.90", "reasons": ["outside menu-curator may-modify remit"], ...}]}

→ tools/call propose_concept {"curie": "pepper:SplitBill", "kind": "process", "realizes": ["dine:Checkout"], "doc": "Splitting one bill into several payments at the table."}
← {"curie": "pepper:SplitBill", "file": "ontology/pepper.gloss.yaml", "markers_rewritten": 1, "next": "link to it with @gloss? ... pepper:SplitBill; a human accepts it with: gloss accept --concept pepper:SplitBill", "status": "proposed"}

→ tools/call impact_of {"paths": ["api/ordering/services/allergen_guard.py"]}
← [{"path": "api/ordering/services/allergen_guard.py", "boundary": "dineb:api", "concepts": [{"curie": "dine:AllergenRule", "criticality": "critical", "criticality_from": "declared", "tests": ["api/tests/test_allergen_guard.py"]}, {"curie": "pepper:AllergenGuard", "criticality": "critical", "criticality_from": "dine:AllergenRule", "tests": [...]}], "criticality": "critical"}]

### gloss mcp with GLOSS_ACTOR=agent:allergen-auditor
→ tools/call propose_link {"path": "api/tests/test_allergen_guard.py", "relation": "verifies", "target": "dine:AllergenRule", "conf": 0.95}
← {"current_drift": {"gaps": 0, "orphans": 0, "rogues": 0, "violations": 2}, "gate": "SOFT", "proposals": [{"gate": "SOFT", "marker": "# @gloss? verifies dine:AllergenRule conf=0.95", "reasons": ["existing concept, valid, inside allowed"], ...}]}

$ sed -n '/SplitBill:/,$p' ontology/pepper.gloss.yaml   # what propose_concept wrote
  SplitBill:
    kind: process
    realizes: dine:Checkout
    doc: "Splitting one bill into several payments at the table."
    proposed: true
    proposed-by: agent:menu-curator
```

What this shows:

- The alias search works as documented: the kitchen's word `chit` finds `KitchenTicket`.
- `propose_link` hands the agent the exact marker line and its gate, including the remit reason.
- `propose_concept` takes `realizes`, which the CLI's `propose --from-new` ignores. The concept it writes is a new capability of the API, so the next session reports two violations until a human adds it to the manifest.
- The last call is the critical-link mismatch again. Inside its remit, the allergen-auditor is told SOFT for a link to the critical rule, and the PR gate will call it HARD.

## Run it

```sh
export GLOSS=$PWD/../../.tools/bin/gloss      # from this directory, after scripts/install-gloss.sh
$GLOSS check && $GLOSS drift && $GLOSS status  # the tables above
demo/remit.sh                                  # remit gate, critical gate, context --changed
demo/review.sh                                 # accept --concept, reject --concept, removed, export --prov
demo/mcp.py                                    # the MCP server over stdio
demo/tour.sh                                   # hook files, context with and without an actor, agents, impact, status, coverage, export --prov, doctor
```

## How it was adopted

The code was written first with no GlossMark files. Then, in order:

1. `gloss init --dry-run` guessed `ka:`/`kai:`/`kab:` from the directory name (C1). This time it placed manifests correctly on `api/`, `db/` and `kds/`. The dry run did not list the hook files it would write.
2. `gloss init --core dine --impl pepper --iri https://onto.pepperrow.example/` gave the boundary prefix `dineb:`.
3. Only `.github/workflows/gloss.yml` was deleted. `gloss hook install --skill` left the existing hook files unchanged and added the skill.
4. The core and implementation tiers and the manifests were written by hand.
5. `gloss suggest --write` made 80 proposals: 21 were kept, 3 retargeted and 56 deleted, every test proposal among them. The subagents wrote the test markers in their own passes.
6. The markers `suggest` cannot see were written by hand: both entry points, the agent files, the skills, AGENTS.md, CLAUDE.md and the docs.
7. `gloss accept --policy`, then `gloss accept --all`. All nine `scope=file` agent-layer links went stale on acceptance (F-ADOPT-8) and were re-recorded by the documented workaround.
8. Each subagent's pass was built under its own `GLOSS_ACTOR`, and `agent:claude-code` accepted ten of the resulting proposals by id and rejected one.
9. `gloss agents --write AGENTS.md` generated the vocabulary block.

Every friction point is in [ADOPTION-NOTES.md](ADOPTION-NOTES.md).
