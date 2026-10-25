# Contributing

This repository has two halves with opposite contracts. Know which one you are touching.

| | `showcase/` | `lab/` |
| --- | --- | --- |
| Purpose | Show new users GlossMark on realistic stacks | Probe GlossMark's modelling and turn rough edges into issues |
| Stability | Stable. Every finding is intentional and documented | Allowed to break, allowed to be ugly |
| CI | `showcase.yml` on every push and PR; failures block | `lab.yml` weekly and on demand; `continue-on-error` |
| Output | A README with a narrative and a documented-drift table, plus golden files | `HYPOTHESIS.md` and `FINDINGS.md` |
| Changes need | Golden files, README table and code changed together | A finding written so it can be pasted into a GlossMark issue |

## The pinned tool

Everything runs the GlossMark pinned in `GLOSS_REF`: a release tag, or a commit on GlossMark main (currently the v0.3.0 release). Install it with `scripts/install-gloss.sh`, which puts the binary in `.tools/bin/gloss` (gitignored): a tag downloads the release binary through the installer fetched from that tag, a commit is built with `go install` (Go 1.24). Do not build GlossMark another way for this repo, and never use a `gloss` from your `PATH`: the scripts take `$GLOSS` and default to the pinned binary. The README's [Tracking GlossMark](README.md#tracking-glossmark) section says how to bump the pin.

```sh
sh scripts/install-gloss.sh
export GLOSS=$PWD/.tools/bin/gloss
scripts/ci-local.sh            # every showcase check, as CI runs it
```

## Showcase contract

A showcase example is stable. Its README tells the story of the system and its two tiers, then a table with three columns, **derived from code**, **declared** and **result**, covering every drift finding the example produces. CI enforces that table:

1. `gloss check` exits 0 and its output matches `expected-check.txt`, so a new lint warning cannot slip in.
2. `gloss drift --fail-on <kinds>` passes. The kinds are the ones that must never appear in that workspace, listed in `showcase/workspaces.tsv`.
3. The full `gloss drift` output matches `expected-drift.txt`. A new finding or a vanished intentional one fails the build.
4. `gloss build` changes nothing under `.glossmark/`: the committed graph and ledger are current.
5. Multi-repo examples also compare `gloss landscape` with `expected-landscape.txt` (`showcase/landscapes.tsv`).

When you change a showcase example on purpose, change the code, rebuild, regenerate the golden files with `UPDATE=1 scripts/ci-local.sh`, and update the README table in the same commit. Review the golden diff: it is the drift you are documenting.

### Workspace registry

`showcase/workspaces.tsv` has one row per workspace (a directory with a `glossmark.yaml`):

| Column | Meaning |
| --- | --- |
| root | path from the repo root |
| fail-on | comma-separated finding kinds that must never appear, or `none`. GlossMark rejects an unknown kind (exit 2); `scripts/check-workspace.sh` checks the list first so the error names the workspace |
| use-action | `true` when the workspace has no intentional violation, value-drift, dangling or overdue finding, so the GlossMark Action can run it |
| coverage-fail-under | passed to `gloss coverage --fail-under`; `current` is the ratchet, `0` disables |

The Action hard-codes `gloss drift --fail-on violation,value-drift,dangling,overdue`, so a workspace that documents one of those findings sets `use-action` to `false` and runs on the pinned binary only. The Action gates `gloss diff` at HARD by default; here it runs with `fail-on: none`, because every PR in this repository edits ontologies and manifests, which is HARD by construction. The impact comment is informational.

### Behaviours that need two git states

A HARD gate on a published change, a `stale` link and a `removed` marker need a before and an after. Each example that shows one ships a script under its `demo/` directory. The script copies the workspace to a temporary directory, commits the before-state, applies the change and runs `gloss diff --base HEAD`. CI does not run them; their expected output is in the example README.

### Conventions

- **Actor.** Links were written by an agent. Every `gloss` command that writes the ledger runs with `GLOSS_ACTOR=agent:claude-code`, except where an example deliberately shows another actor. Never set a human actor for work no human reviewed.
- **Adoption first.** Each example's code was written with no GlossMark files, then adopted with `gloss init`, the adopt-glossmark skill, `gloss suggest`, `gloss doctor`, `gloss check` and `gloss drift`. Only then were the advanced features and documented drift added. Friction goes in `lab/ADOPTION-LOG.md`.
- **What `gloss init` writes that is removed here.** `init` writes `.github/workflows/gloss.yml` inside the workspace, which GitHub never runs in a subdirectory; this repo deletes it and drives CI from the root. It also writes `.claude/settings.json` and `.mcp.json`; only the agent example keeps them.
- **Marking.** Follow GlossMark's `docs/MARKING.md`: one marker per public surface, `scope=file` when a file is about one concept, `presents`/`hosts` for pages and shells, quoted `doc:` everywhere, `@gloss?` with `conf=` for proposals, `ns:NEW:Name` plus `gloss propose --from-new` for a new concept. Never hand-edit an ontology to make a link resolve.
- **Inert code.** Code is valid and idiomatic but never built. Do not add lockfiles or install dependencies.

## Lab contract

Each experiment in `lab/<name>/` has:

- `HYPOTHESIS.md`: the modelling question, and what "GlossMark handles this well" would look like.
- A minimal codebase and ontology that probe it.
- `FINDINGS.md`: one section per finding, each with **Problem**, **Repro** (a path in this repo and the command), **Proposed change** (feature, relation, lint rule or doc change) and **Done when** (testable). Copy a section into a GlossMark issue as is.
- Optionally `run.sh`, which `lab.yml` runs instead of the default `check` + `drift`.

A lab experiment may contain violations, broken links and lint errors. That is the point. Do not move anything from `lab/` to `showcase/` without giving it a documented-drift table and golden files.

## Commits

One commit per unit: the skeleton, each showcase example, each lab experiment. Commit `.glossmark/graph.jsonl`, `.glossmark/ledger.jsonl`, `.glossmark/context.jsonld`, `glossmark.lock` and, once `gloss lock` has written them, the vendored imports under `.glossmark/imports/`, with the change that produced them. A change of `GLOSS_REF` goes in the commit that regenerates the golden files.
