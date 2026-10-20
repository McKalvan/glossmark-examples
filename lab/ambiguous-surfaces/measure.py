"""Measure one variant workspace of lab/ambiguous-surfaces.

Usage: python3 -I measure.py <gloss> <workspace> <tmpdir> <surface-path>...

Prints one Markdown table row: check, drift findings, coverage, the criticality
of each surface file (graph artifact node, then gloss impact), the surface
boundary's criticality, and where the engineering view (zoom container) places each core concept.
Writes nothing inside the workspace (view --json goes to <tmpdir>).
"""
import json
import os
import re
import subprocess
import sys

KINDS = ["violation", "gap", "presented-only", "untested", "orphan", "dangling"]


def run(gloss, ws, *args):
    p = subprocess.run([gloss, *args, "--root", ws], capture_output=True, text=True, cwd=ws)
    return p.stdout, p.stderr


def main():
    gloss, ws, tmp = sys.argv[1], os.path.abspath(sys.argv[2]), sys.argv[3]
    surfaces = sys.argv[4:]
    _, err = run(gloss, ws, "check")
    codes = sorted(set(re.findall(r"\[(GM\d+)\]", err)))
    m = re.search(r"(\d+) errors?, (\d+) warnings?", err)
    check = f"{m.group(1)}e/{m.group(2)}w" + (" " + ",".join(codes) if codes else "") if m else "?"

    out, _ = run(gloss, ws, "drift", "--fail-on", "none", "--format", "json")
    data = json.loads(out or "{}")
    findings = data.get("findings", data if isinstance(data, list) else [])
    drift = []
    for k in KINDS:
        names = sorted({f.get("concept") or f.get("boundary") or f.get("msg", "")[:40] for f in findings if f.get("kind") == k})
        if names:
            drift.append(f"{k}: " + ", ".join(names))

    out, _ = run(gloss, ws, "coverage", "--format", "json")
    cov = json.loads(out)
    coverage = f"{cov['concepts_covered']}/{cov['concepts_in_scope']}"

    nodes = [json.loads(l) for l in open(os.path.join(ws, ".glossmark/graph.jsonl"))]
    arts = [n for n in nodes if n.get("node") == "artifact"]
    bounds = {n["curie"]: n for n in nodes if n.get("node") == "boundary"}
    crit = []
    sb = set()
    for s in surfaces:
        levels = sorted({f"{a.get('criticality', 'none')}" for a in arts if a.get("path") == s}) or ["unmarked"]
        out, _ = run(gloss, ws, "impact", s)
        im = re.search(r"criticality (\w+) \(via ([^)]+)\)", out)
        hdr = re.search(r"\[(\w+), ([^,\]]+)", out)
        if hdr:
            sb.add(hdr.group(2))
        crit.append(f"`{os.path.basename(s)}` graph {'/'.join(levels)}, impact {im.group(1) if im else 'none'}")
    bcrit = ", ".join(f"{b} {bounds[b].get('criticality', 'none')}" for b in sorted(sb) if b in bounds)

    os.makedirs(tmp, exist_ok=True)
    vj = os.path.join(tmp, "views.json")
    run(gloss, ws, "view", "--json", "-o", vj)
    views = json.load(open(vj))
    eng = next(v for v in views["views"] if v["name"] == "engineering")
    place = ", ".join(f"{n['id']}→{n.get('boundary', '-')}" for n in eng["nodes"]
                      if n.get("type") == "concept" and n.get("tier") == "core")

    name = os.path.relpath(ws, os.path.dirname(os.path.dirname(ws)))
    print(f"| {name} | {check} | {'; '.join(drift) or 'none'} | {coverage} | {'; '.join(crit)} | {bcrit} | {place} |")


if __name__ == "__main__":
    main()
