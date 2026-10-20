"""Score `gloss suggest --format json` against truth.tsv.

usage: python3 score.py truth.tsv core.gloss.yaml suggest.json [label] [impl.gloss.yaml]
An implementation target (.X or ops:X) is scored as the core concept X realizes.
useful   = right surface, an acceptable concept (relation not judged)
retarget = right surface, wrong domain concept
echo     = right surface, but the concept only restates the code name (no domain concept means it)
noise    = a surface that should stay unmarked
recall   = truth surfaces with a useful proposal / truth surfaces whose concept exists in the variant
"""
import json
import re
import sys

truth_path, onto_path, sug_path = sys.argv[1:4]
label = sys.argv[4] if len(sys.argv) > 4 else sug_path
realizes = {}
if len(sys.argv) > 5:
    for m in re.finditer(r"^  (\w+):\n(?:    .*\n)*?    realizes: wh:(\w+)", open(sys.argv[5]).read(), re.M):
        realizes[m.group(1)] = m.group(2)
truth = {}
for ln in open(truth_path):
    if ln.startswith("#") or not ln.strip():
        continue
    path, sym, acc, nested = ln.rstrip("\n").split("\t")
    truth[(path, sym)] = (set(acc.split(",")), nested == "1")
concepts = set(re.findall(r"^  (\w+):", open(onto_path).read(), re.M))
sugs = json.load(open(sug_path)) or []
useful, retarget, echo, noise = [], [], [], []
domain = set().union(*(acc for acc, _ in truth.values()))
for s in sugs:
    t = s["target"]
    key, name = (s["path"], s["symbol"]), t[1:] if t.startswith(".") else t.split(":", 1)[1]
    if not t.startswith("wh:"):
        name = realizes.get(name, name)
    if key not in truth:
        noise.append(s)
    elif name in truth[key][0]:
        useful.append(s)
    elif name not in domain:
        echo.append(s)
    else:
        retarget.append(s)
reachable = [k for k, (acc, _) in truth.items() if acc & concepts]
hit = {(s["path"], s["symbol"]) for s in useful}
nested = [k for k in reachable if truth[k][1]]
print(f"{label}: {len(concepts)} concepts, {len(sugs)} proposals: "
      f"{len(useful)} useful, {len(retarget)} retarget, {len(echo)} echo, {len(noise)} noise; "
      f"precision {len(useful) / len(sugs) * 100 if sugs else 0:.0f}%; "
      f"recall {len(hit)}/{len(reachable)} surfaces ({len(nested)} of them methods suggest never scans)")
def conf(xs):
    return f"{sum(x['conf'] for x in xs) / len(xs):.2f}" if xs else "-"


print(f"  mean conf: useful {conf(useful)}, retarget {conf(retarget)}, echo {conf(echo)}, noise {conf(noise)}")
for tag, xs in (("useful", useful), ("retarget", retarget), ("echo", echo), ("noise", noise)):
    for s in xs:
        print(f"  {tag:8} {s['path']}:{s['line']} {s['symbol']} {s['relation']} {s['target']} [{s['matched']}]")
