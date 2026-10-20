# Findings from adopting the showcase examples

Issue-ready findings distilled from [ADOPTION-LOG.md](ADOPTION-LOG.md). Each section can be pasted into a GlossMark issue as is: the problem, a repro in this repository, a proposed change, and a testable done-when. All repros use the v0.1.0 binary from `scripts/install-gloss.sh` (`$GLOSS`).

## F-ADOPT-1: init places manifests on grouping directories in a monorepo

**Problem.** `gloss init` writes one manifest per top-level source directory. In a monorepo the top level is a grouping (`apps/`, `services/`), and the boundaries a reader cares about are the deployables beneath it. A directory of Kubernetes YAML (`deploy/`) gets no manifest. The guessed prefixes (`cb:`, `cbi:`, `cbb:`) are initials of the directory name, and the boundary prefix has no override flag.

**Repro.** Copy `showcase/clinic-booking` without `glossmark.yaml`, `ontology/`, `.glossmark/` and every `.gloss.yaml`, then run `$GLOSS init --dry-run`. It plans `apps/.gloss.yaml` and `services/.gloss.yaml`, not `apps/web`, `services/booking-api` and `services/reminders`, and nothing for `deploy/`.

**Proposed change.** Treat a top-level directory whose children each look like a project (their own `package.json`, `go.mod`, `pyproject.toml`, `Dockerfile`) as a grouping and plan one manifest per child. Plan a manifest for any directory of Kubernetes, Helm or Terraform files. Add `--boundary-prefix`.

**Done when.** `init --dry-run` on the stripped clinic-booking plans manifests for `apps/web`, `services/booking-api`, `services/reminders` and `deploy`, and `--boundary-prefix lk` changes the boundary prefix.

## F-ADOPT-2: init and doctor assume the workspace is the git root

**Problem.** In a repository with several GlossMark workspaces (this one, any monorepo of products), `gloss init` writes `.github/workflows/gloss.yml` into the workspace, where GitHub never runs it. `gloss doctor` looks for the Action only inside the workspace and reports a warning when CI is pinned correctly at the git root.

**Repro.** `cd showcase/clinic-booking && $GLOSS doctor` prints `! CI pins: no GitHub workflow or pre-commit config references GlossMark`, although `.github/workflows/showcase.yml` at the repository root runs `mckalvan/glossmark@v0.1.0` with `root: showcase/clinic-booking`.

**Proposed change.** Find the git root. When it differs from the workspace, `init` prints the workflow snippet with `root:` set instead of writing a file, and `doctor` searches the git root's workflows for the Action with a matching `root:`.

**Done when.** `doctor` in `showcase/clinic-booking` reports `✓ CI pins`, and `init` in a subdirectory of a git repository writes no `.github/` directory.

## F-ADOPT-3: doctor reports an unrelated gloss on PATH as healthy

**Problem.** `gloss doctor` checks that some `gloss` is on `PATH` and prints the version of the binary running the check, not of the one it found. The hook (`gloss context ... || true`), the MCP entry and the Makefile target all call that bare `gloss`. When `PATH` has a different program of the same name, agents silently get no briefing and no MCP server, and `doctor` says everything is fine.

**Repro.** On any machine with an unrelated `/usr/bin/gloss` (here: a GL benchmark that prints frame rates), run `.tools/bin/gloss doctor` in a workspace. It prints `✓ gloss on PATH: /usr/bin/gloss (this build is 0.1.0)`.

**Proposed change.** `doctor` runs `<found> version` and compares the first line with its own. `hook install` and `init` write the absolute path of the running binary, or a `GLOSS` variable, into the hook and the MCP entry when the `PATH` lookup does not resolve to the running binary.

**Done when.** With an unrelated `gloss` first on `PATH`, `doctor` reports `✗ gloss on PATH: /usr/bin/gloss is not GlossMark`, and `hook install` writes a command that runs the right binary.

## F-ADOPT-4: doc gaps found during adoption

**Problem.** Three statements in the docs are incomplete:

1. FILE-FORMATS.md says the derived `allowed` set contains concepts the manifest declares under `realizes`, `produces`, `consumes`, `publishes` and `subscribes`. In v0.1.0 it also contains `holds`, `presents` and `hosts` (`gloss check --explain` shows them).
2. Nothing says which `--fail-on` kind names exist. They are the finding kinds of ADVANCED.md, spelled `value-drift` and `presented-only`; `stale`, `rogue` and `proposed` are accepted but never fail (see F-ADOPT-11).
3. GOVERNANCE.md does not say that a curated view does not count as "changed" when a published value of a concept it names drifts (`demo/gates.sh` in clinic-booking reports `Views changed: engineering` only).

**Repro.** `cd showcase/clinic-booking && $GLOSS check --explain` shows `clinic:Patient` in `clinicb:db`'s allowed set, which declares it only under `holds`. `showcase/clinic-booking/demo/gates.sh` shows the view list.

**Proposed change.** Fix the list in FILE-FORMATS.md, add a `--fail-on` kind table to ADVANCED.md, and either count value drift as a change to every view that names the concept or document that it does not.

**Done when.** The docs match `check --explain`, and the gates demo either lists `published-values` among the changed views or the docs say why not.

## F-ADOPT-5: suggest text output truncates silently at 80

**Problem.** `gloss suggest --format text` prints at most 80 proposals with no indication that more exist. `--format json` and the default patch output contain all of them.

**Repro.** Run `$GLOSS suggest --format text | wc -l` and `$GLOSS suggest --format json | jq length` on a copy of `showcase/clinic-booking` with every `@gloss` line removed: 80 and 126.

**Proposed change.** Print every proposal, or end with `… and 46 more (use --format json)`.

**Done when.** The line counts agree, or the text output ends with the remainder count.

## F-ADOPT-6: inherit reports a child's undeclared realizes at the parent

**Problem.** When a system declares `realizes: inherit` and one of its containers derives `realizes` from its code but declares no `realizes` of its own, the container is not compared (it declares nothing), and every concept it realizes becomes a violation at the system. Each violation line repeats the full declared and derived sets. In clinic-booking that was five lines of roughly 600 characters each, all pointing at the root manifest, for one omission in `apps/web/.gloss.yaml`.

**Repro.** In `showcase/clinic-booking/apps/web/.gloss.yaml`, delete the `realizes:` line and run `$GLOSS drift`.

**Proposed change.** When a parent inherits and a child derives a relation it does not declare, report one finding on the child (`clinicb:web realizes 5 concepts but declares no realizes; its parent inherits`), and print the sets once per boundary rather than once per violating concept.

**Done when.** The repro prints one finding naming `apps/web/.gloss.yaml`.

## F-ADOPT-7: publishes-value does not count as an implementation

**Problem.** A constant marked `@gloss publishes-value .X scope=line` binds X's published value to code, but it does not lift X to `realizes` on its boundary, and X counts as having no artifact. The boundary that owns the setting cannot declare it without a second, redundant `implements` marker on the same line. Separately, `value-from` takes one location, so a value duplicated in a second language (the 24-hour window in the Go API and in the TypeScript page) cannot be bound twice.

**Repro.** In `showcase/clinic-booking/services/reminders/.gloss.yaml`, add `lark:LeadTimeSetting` to `realizes` and run `$GLOSS drift`: `gap: clinicb:reminders declares realizes lark:LeadTimeSetting but nothing under it implements it`.

**Proposed change.** Let `publishes-value` lift as `implements` for the concept it names (it is the code that holds the value). Allow `value-from` to take a list, every entry of which must agree with `value:`.

**Done when.** The repro reports no gap, and a two-entry `value-from` on `lark:CancellationPolicy` reports value-drift when either location changes.

## F-ADOPT-8: accepting a scope=file proposal makes it stale, and it cannot be re-confirmed

**Problem.** Three things combine. The fingerprint of a `scope=file` anchor hashes the whole file, marker line included. `gloss accept` rewrites `@gloss?` to `@gloss` in that file. So every accepted file-scope proposal is stale immediately. Then the drift message says `re-confirm with gloss accept <id>`, and `gloss accept <id>` refuses with `is not proposed; nothing to accept`. There is no command that re-confirms a stale link.

**Repro.**
```sh
cd "$(mktemp -d)" && cp -r <repo>/showcase/clinic-booking ws && cd ws
sed -i 's|^// @gloss verifies .BookingPage|// @gloss? verifies .BookingPage|' apps/web/tests/booking.spec.ts
$GLOSS build -q && $GLOSS accept --all && $GLOSS build -q && $GLOSS drift | grep -A1 Stale
$GLOSS accept <the id it prints>      # → is not proposed; nothing to accept
```

**Proposed change.** Exclude `@gloss` marker lines from every fingerprint (they are metadata about the code, not the code). Make `gloss accept <id>` on a stale link re-confirm it: record the current fingerprint and set the status back to `accepted`, as the message already promises.

**Done when.** The repro shows no stale link after `accept --all`, and `gloss accept <id>` on a link made stale by a real edit sets it to `accepted`.

## F-ADOPT-9: criticality suggest has no memory of a review

**Problem.** `gloss criticality suggest` proposes `high` for every constraint and every published concept that is not already at `high` or above, including implementation concepts that would inherit the level from the core concept they realize. When a reviewer lowers the core concept to `medium` on purpose, the implementation concept that inherits `medium` is proposed as `high` on every later run.

**Repro.** `cd showcase/clinic-booking && $GLOSS criticality suggest` proposes `lark:LeadTimeSetting → high`, although `clinic:ReminderLeadTime`, which it realizes, was reviewed and set to `medium` with a comment.

**Proposed change.** Skip a concept whose effective level is inherited from a concept with a declared level: the declaration is the review. Do not propose a level for an implementation concept at all when the concept it realizes is unclassified; propose it on the core concept instead.

**Done when.** The repro prints `0 suggestions`.

## F-ADOPT-10: the criticality floor misses unmarked files in the export

**Problem.** `criticality-floor: true` raises every *artifact* beneath a boundary. `gloss impact` handles an unmarked file correctly: it reports the boundary's floor and asks for a link. The SQLite export does not: a file with no marker is not an artifact node, so the query GOVERNANCE.md recommends for "the files that deserve the most careful review" (`SELECT path FROM nodes WHERE node='artifact' AND criticality IN ('high','critical')`) misses exactly the files a floor exists to catch. In clinic-booking, `db/migrations/0006_roles.sql` grants database roles access to patient tables and is absent from the export.

**Repro.** `cd showcase/clinic-booking && $GLOSS impact db/migrations/0006_roles.sql` reports `criticality high (via clinicb:db)`. `$GLOSS export --sqlite /tmp/g.db && sqlite3 /tmp/g.db "SELECT path FROM nodes WHERE path LIKE 'db/%'"` lists 0001 to 0004 and not 0005 or 0006.

**Proposed change.** Under a floor, export every in-scope file beneath the boundary as a node (`node='file'`, or an artifact of kind `file`) carrying the floor level, so the governance query and the viewer's criticality filter see what `impact` already sees.

**Done when.** The export lists `db/migrations/0006_roles.sql` with `criticality = 'high'`.

## F-ADOPT-11: unknown finding kinds in --fail-on are ignored

**Problem.** `gloss drift --fail-on <kinds>` and `gloss landscape --fail-on <kinds>` accept any string. An unknown kind is silently ignored, so a typo (`valuedrift`, `violations`) disables that part of the gate and CI stays green. Every real kind works, including `stale` and `rogue`.

**Repro.** `cd showcase/clinic-booking && $GLOSS drift --fail-on bogus; echo $?` prints `0`.

**Proposed change.** Reject unknown kinds with exit 2 and the list of valid ones.

**Done when.** The repro exits 2 and names the valid kinds.

## F-ADOPT-12: the Action's PR comment is not keyed by root, so a matrix of workspaces overwrites one comment

**Problem.** A repository with several GlossMark workspaces runs the Action once per workspace (`root:` differs per matrix job), as this repository's `showcase.yml` does. The comment step finds an existing comment by the fixed marker `<!-- glossmark-impact -->` and updates it. Every job therefore rewrites the same comment, and the pull request shows only the impact of whichever workspace finished last.

**Repro.** `action.yml` at v0.1.0, lines 84 to 89: `const marker = '<!-- glossmark-impact -->'` and `comments.find(c => c.body && c.body.includes(marker))`, with no reference to `inputs.root`. Any pull request on this repository that touches two showcase examples shows one impact comment.

**Proposed change.** Include the root in the marker (`<!-- glossmark-impact:showcase/clinic-booking -->`) and in the comment heading, or add a `comment-key` input.

**Done when.** A pull request touching two showcase workspaces gets two impact comments, one per root, and a re-run updates each in place.
