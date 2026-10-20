# Hypothesis: GlossMark can be adopted on concept-poor legacy code

## The question

Much of the code a team would most like to explain has no domain vocabulary in it. Logic sits in `helpers.py`, `utils/`, `common/StringUtils.java`, `misc.js` and a `functions.php` every page includes. The classes are god classes called `Manager`, `Processor` and `Handler`, the functions are `process_data`, `handle` and `doIt`, and the tables are `tbl_data` and `tbl_queue`. The domain is real, but the names hide it. It shows only in a docstring, a column name or the supervisor's head.

`opstool/` is such a codebase: a warehouse's internal tool, 23 files in Python, PHP, JavaScript, Java, SQL and shell. It reconciles cycle counts, tops up pick faces, builds pick carts per truck cutoff while keeping incompatible hazmat classes apart, confirms picks on handhelds, grades customer returns, and prints SSCC carton labels. None of those words appear in a function, class or file name.

What does GlossMark v0.1.0 give a new adopter here? What does `gloss suggest` propose when every name is generic, and what does a good adoption look like?

## Why it matters

`gloss suggest` is step 6 of the adopt-glossmark skill and the first thing an adopter or agent runs. GlossMark's value is highest on code like this, where the ontology carries knowledge the code does not. Yet the one tool that bridges code to ontology works from names, and names are what this code lacks. If suggest is confidently wrong here, the first PR plants wrong links that look reviewed. If the adoption recipe has no answer for god classes and utility files, adopters either mark everything or nothing.

## Setup

- `opstool/` was written first with no GlossMark files, then adopted with `gloss init --dry-run`, `gloss init --core wh --impl ops`, the skill's steps, `gloss suggest --format json`, `gloss suggest --write`, a review of every proposal, hand-written markers, `gloss check`, `gloss build`, `gloss drift`, `gloss coverage` and `gloss doctor`.
- `variants/` holds three core tiers a new adopter could write. **naive** is inferred from the code's own names, as an adopter with no domain expert would write it. **domain** is what a warehouse supervisor would name. **aliases** is domain plus `aliases:` holding the abbreviations the code uses (`rma`, `loc`, `cnt`, `zpl`, `batch`).
- `truth.tsv` lists the 39 public surfaces and the concept(s) each should link to. `score.py` scores `suggest --format json` against it. A **useful** proposal has the right surface and the right concept, whatever the relation. A **retarget** has the right surface and the wrong concept. An **echo** has the right surface, but its concept only restates the code name. **Noise** is a surface that should stay unmarked.
- `evidence.py` lists, per surface, the evidence suggest does not read: docstrings, comments and the `tbl_*` tables the body touches.
- `run.sh` reproduces every number and probe in a temp directory.

## What "GlossMark handles this well" would look like

1. **Precision.** With the domain or aliases tier, `run.sh`'s scoring shows at least 70 % useful proposals, and no proposal on `utils/` glue or one-letter helpers.
2. **Generic words do not match.** `process`, `handle`, `Manager`, `run` and fragments of a concept name never match a domain concept alone. Raising `--min-score` raises precision.
3. **Recall from more than names.** With the domain tier, suggest reaches at least half of the 39 surfaces. It uses the evidence the code does have: docstrings and comments, the tables a function touches, and tests that call already-linked code.
4. **God classes.** suggest proposes links on methods inside `Manager`, `Processor`, `Handler` and `StringUtils`, where the logic lives.
5. **Anchors.** Two methods with the same generic name in different classes of one file are two artifacts (`InboundHandler.process`, `OutboundHandler.process`).
6. **A thin ontology.** With an empty or thin core tier, suggest says why it has nothing. It proposes `ns:NEW:` concepts or `internal` mechanism concepts from clusters of code (shared tables, shared callers) instead of printing `null`.
7. **Reviews stick.** A proposal rejected with `gloss reject` stops counting in `check` and `drift` and is not proposed again.
8. **A minimal adoption tells the truth.** A domain core tier, a small implementation tier naming the hidden mechanisms, and markers on the mechanisms only give 0 violations and 0 gaps. The remaining orphans and untested concepts are real gaps in the code, not artefacts of the method.
9. **Glue can be described without distortion.** An `internal: true` tier for `utils/`, the god class and the cron job does not change concept coverage or the untested list.
10. **Unmarked is a valid start.** With no markers, `gloss drift` still says something useful about where the domain lives.
