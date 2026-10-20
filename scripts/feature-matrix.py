#!/usr/bin/env python3
"""Render and verify the README feature matrix.

showcase/feature-matrix.tsv lists, per matrix row, which example shows it and
the file that shows it: `path`, `path:line`, or `path@@text` (the first line containing text). Rows come from GlossMark v0.1.0's
docs/ADVANCED.md, docs/FILE-FORMATS.md and README.md; showcase/matrix-rows.tsv
fixes their order. This script:
  --check   fails when a row has no evidence, or a cited file or line does not exist
  --write   rewrites the table between the matrix markers in README.md
"""
import collections, csv, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLES = ["clinic-booking", "freight-federation", "claims-events", "kitchen-agents", "library-legacy"]
BEGIN, END = "<!-- feature-matrix:begin -->", "<!-- feature-matrix:end -->"


def read_tsv(name):
    with open(os.path.join(ROOT, name), newline="") as f:
        return [r for r in csv.reader(f, delimiter="\t") if r and not r[0].startswith("#")]


def main(argv):
    rows = read_tsv("showcase/matrix-rows.tsv")          # section, row, note
    evidence = collections.defaultdict(lambda: collections.defaultdict(list))
    problems = []
    for section, row, example, ref in read_tsv("showcase/feature-matrix.tsv"):
        if example not in EXAMPLES:
            problems.append(f"{row}: unknown example {example}")
            continue
        pattern = None
        if "@@" in ref:
            ref, pattern = ref.split("@@", 1)
        path, _, line = ref.partition(":")
        full = os.path.join(ROOT, "showcase", example, path)
        if not os.path.exists(full):
            problems.append(f"{row} [{example}]: {path} does not exist")
        elif pattern:
            hits = [i for i, l in enumerate(open(full, errors="replace"), 1) if pattern in l]
            if hits:
                line = str(hits[0])
            else:
                problems.append(f"{row} [{example}]: {path} has no line containing {pattern!r}")
        elif line:
            n = sum(1 for _ in open(full, errors="replace"))
            if not (line.isdigit() and 1 <= int(line) <= n):
                problems.append(f"{row} [{example}]: {path} has no line {line}")
        evidence[(section, row)][example].append((path, line))
    known = {(s, r) for s, r, *_ in rows}
    for key in evidence:
        if key not in known:
            problems.append(f"evidence for unknown row {key}")

    out, current = [], None
    for section, row, *rest in rows:
        note = rest[0] if rest else ""
        if section != current:
            current = section
            out += ["", f"**{section}**", "", "| Row | " + " | ".join(EXAMPLES) + " |", "| --- |" + " :-: |" * len(EXAMPLES)]
        cells = []
        for ex in EXAMPLES:
            refs = evidence[(section, row)].get(ex, [])
            cells.append(" ".join(f"[{'✓' if i == 0 else i + 1}](showcase/{ex}/{p}{'#L' + l if l else ''})" for i, (p, l) in enumerate(refs)))
        if not any(cells) and not note.startswith("uncoverable"):
            problems.append(f"{section} / {row}: no example shows it")
        label = f"{row} ({note})" if note else row
        out.append(f"| {label} | " + " | ".join(cells) + " |")
    table = "\n".join(out).strip("\n")

    if "--write" in argv:
        p = os.path.join(ROOT, "README.md")
        s = open(p).read()
        a, b = s.index(BEGIN) + len(BEGIN), s.index(END)
        open(p, "w").write(s[:a] + "\n" + table + "\n" + s[b:])
    for pr in problems:
        print("matrix:", pr)
    covered = sum(1 for s, r, *_ in rows if evidence[(s, r)])
    print(f"matrix: {covered}/{len(rows)} rows have evidence, {len(problems)} problems")
    return 1 if problems and "--check" in argv else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
