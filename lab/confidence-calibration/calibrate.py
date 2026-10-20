#!/usr/bin/env python3
"""Recompute the calibration tables from data/labels.csv (stdlib only).

python3 calibrate.py [path/to/labels.csv]
"""
import csv
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROWS = list(csv.DictReader(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "data", "labels.csv"))))
for r in ROWS:
    r["conf"] = float(r["conf"])
BANDS = ["<0.5", "0.5-0.6", "0.6-0.7", "0.7-0.8", "0.8-0.9", ">=0.9"]
THRESHOLD = 0.7
GATE_SHARE, GATE_PRECISION = 0.80, 0.90


def pct(a, b):
    return f"{100 * a / b:5.1f}%" if b else "    -"


def stats(rows):
    c = collections.Counter(r["label"] for r in rows)
    return len(rows), c["correct"], c["near-miss"], c["wrong"]


def table(title, rows, key, order):
    print(f"\n{title}")
    print(f"  {'':10} {'n':>4} {'correct':>7} {'near':>5} {'wrong':>5}  {'precision':>9}  {'lenient':>8}")
    groups = collections.defaultdict(list)
    for r in rows:
        groups[key(r)].append(r)
    for k in order or sorted(groups):
        n, c, nm, w = stats(groups.get(k, []))
        print(f"  {str(k):10} {n:4} {c:7} {nm:5} {w:5}  {pct(c, n):>9}  {pct(c + nm, n):>8}")
    n, c, nm, w = stats(rows)
    print(f"  {'all':10} {n:4} {c:7} {nm:5} {w:5}  {pct(c, n):>9}  {pct(c + nm, n):>8}")


def batch(rows, gate_col):
    hi = [r for r in rows if r["conf"] >= THRESHOLD]
    soft = [r for r in rows if r[gate_col] in ("SOFT", "AUTO")]
    n, c, _, _ = stats(hi)
    ns, cs, _, _ = stats(soft)
    print(f"\n  conf >= {THRESHOLD}: {n} of {len(rows)} proposals ({pct(n, len(rows)).strip()}), precision {pct(c, n).strip()}")
    print(f"  gate SOFT/AUTO (gloss diff): {ns} of {len(rows)} ({pct(ns, len(rows)).strip()}), precision {pct(cs, ns).strip()}")
    met = len(rows) and ns / len(rows) >= GATE_SHARE and ns and cs / ns >= GATE_PRECISION
    print(f"  Phase 2 gate (>= {GATE_SHARE:.0%} auto-accept at >= {GATE_PRECISION:.0%} precision): {'MET' if met else 'NOT MET'}")
    return hi


def kappa(pairs):
    labels = ["correct", "near-miss", "wrong"]
    n = len(pairs)
    po = sum(a == b for a, b in pairs) / n
    ca, cb = collections.Counter(a for a, _ in pairs), collections.Counter(b for _, b in pairs)
    pe = sum(ca[l] * cb[l] for l in labels) / n / n
    return po, (po - pe) / (1 - pe)


SETS = [
    ("clinic-booking (126, no written allowed: = coordinator's batch)", lambda r: r["codebase"] == "clinic-booking" and r["in_noallowed"] == "1", "gate_noallowed"),
    ("meterworks (46, no written allowed:)", lambda r: r["codebase"] == "meterworks" and r["in_noallowed"] == "1", "gate_noallowed"),
    ("pooled, no written allowed: (172)", lambda r: r["in_noallowed"] == "1", "gate_noallowed"),
    ("pooled, committed manifests (148)", lambda r: r["in_committed"] == "1", "gate_committed"),
]

for title, pred, gate_col in SETS:
    rows = [r for r in ROWS if pred(r)]
    print("=" * 78)
    print(title)
    table("  precision by band", rows, lambda r: r["band"], BANDS)
    table("  precision by exact conf value", rows, lambda r: f"{r['conf']:.2f}", None)
    batch(rows, gate_col)

pooled = [r for r in ROWS if r["in_noallowed"] == "1"]
print("=" * 78)
print("Threshold sweep (pooled, no written allowed:): share of proposals at or above, and their precision")
for t in (0.4, 0.5, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95):
    hi = [r for r in pooled if r["conf"] >= t]
    n, c, _, _ = stats(hi)
    print(f"  conf >= {t:.2f}: {n:4} ({pct(n, len(pooled))}), precision {pct(c, n)}")
print("=" * 78)
print("Why proposals at conf >= 0.7 are not correct (pooled, no written allowed:)")
for k, v in collections.Counter(r["cause"] for r in pooled if r["conf"] >= THRESHOLD and r["label"] != "correct").most_common():
    print(f"  {v:3}  {k}")
print("\nWhy conf >= 0.7 proposals are HARD anyway (pooled, no written allowed:)")
for k, v in collections.Counter(r["hard_reason_noallowed"] or "(none)" for r in pooled
                                if r["conf"] >= THRESHOLD and r["gate_noallowed"] == "HARD").most_common():
    print(f"  {v:3}  {k}")
print("\nAll non-correct proposals by cause (pooled, no written allowed:)")
for k, v in collections.Counter(r["cause"] for r in pooled if r["label"] != "correct").most_common():
    print(f"  {v:3}  {k}")

MECHANICAL = {"package-clause", "test-double", "duplicate-impl-block", "part-of-table"}
kept = [r for r in pooled if r["cause"] not in MECHANICAL]
print("\nWhat-if: suggest skipped package/module clauses, non-test declarations in test files,")
print("Rust impl blocks and SQL indexes/types (causes a syntactic filter can see)")
hi = [r for r in kept if r["conf"] >= THRESHOLD]
n, c, _, _ = stats(hi)
print(f"  {len(kept)} proposals left; conf >= {THRESHOLD}: {n}, precision {pct(c, n).strip()}")

clinic = [r for r in ROWS if r["codebase"] == "clinic-booking"]
po, k = kappa([(r["label"], r["coordinator_label"]) for r in clinic])
print("=" * 78)
print(f"Inter-rater agreement on clinic-booking (lab labels vs coordinator's KEEP map), n={len(clinic)}")
print(f"  raw agreement {po:.1%}, Cohen's kappa {k:.2f}")
m = collections.Counter((r["label"], r["coordinator_label"]) for r in clinic)
labels = ["correct", "near-miss", "wrong"]
print(f"  {'lab \\ coordinator':18}" + "".join(f"{l:>10}" for l in labels))
for a in labels:
    print(f"  {a:18}" + "".join(f"{m[(a, b)]:10}" for b in labels))
cc = [r for r in clinic if r["coordinator_label"] == "correct"]
hi = [r for r in clinic if r["conf"] >= THRESHOLD]
print(f"  coordinator's labels: precision at conf >= {THRESHOLD} = {pct(sum(r['coordinator_label'] == 'correct' for r in hi), len(hi)).strip()}"
      f" ({sum(r['coordinator_label'] == 'correct' for r in hi)} of {len(hi)})")
