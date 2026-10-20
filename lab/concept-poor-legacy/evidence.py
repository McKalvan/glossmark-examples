"""For each surface in truth.tsv, list the evidence `gloss suggest` does not read.

usage: python3 evidence.py truth.tsv ontology.gloss.yaml code-root
doc   = the docstring or the comment just above/inside the declaration names an acceptable
        concept by a word of its name (4+ letters) or one of its aliases
table = the body reads or writes a tbl_* table (a data-access edge suggest could follow)
"""
import re
import sys

truth_path, onto_path, root = sys.argv[1:4]
onto = open(onto_path).read()
words = {}
for m in re.finditer(r"^  (\w+):(.*(?:\n    .*)*)", onto, re.M):
    name, body = m.group(1), m.group(2)
    ws = {w.lower() for w in re.findall(r"[A-Z][a-z]{3,}", name)}
    for a in re.findall(r'aliases: \[([^\]]*)\]', body):
        ws |= {x.strip().strip('"').lower() for x in a.split(",")}
    words[name] = ws

DECL = r"(?:def|class|function|public[\w\s<>,]*?|CREATE TABLE)\s+{}\b|^{}\s*="


def body_of(lines, i):
    ind = len(lines[i]) - len(lines[i].lstrip())
    out = [lines[i]]
    for ln in lines[i + 1:]:
        if ln.strip() and len(ln) - len(ln.lstrip()) <= ind and not ln.strip().startswith(("}", ")", '"""')):
            break
        out.append(ln)
    return out


rows = doc_n = table_n = either = 0
for ln in open(truth_path):
    if ln.startswith("#") or not ln.strip():
        continue
    path, sym, acc, _ = ln.rstrip("\n").split("\t")
    if sym == "(file)":
        continue
    rows += 1
    lines = open(f"{root}/{path}").read().split("\n")
    name = sym.split(".", 1)[1] if sym.startswith("table.") else sym
    idx = next((i for i, l in enumerate(lines) if re.search(DECL.format(re.escape(name), re.escape(name)), l)), None)
    if idx is None:
        print(f"  ?      {path} {sym}: declaration not found")
        continue
    body = body_of(lines, idx)
    above = []
    j = idx - 1
    while j >= 0 and lines[j].strip().startswith(("#", "//", "/*", "*", "--", "@")):
        above.insert(0, lines[j]); j -= 1
    text = " ".join(l for l in above + body[:4]
                    if re.search(r'#|//|/\*|\*|--|"""', l) and "@gloss" not in l).lower()
    hits = sorted(c for c in acc.split(",") if any(w in text for w in words.get(c, ())))
    tables = sorted(set(re.findall(r"tbl_\w+", "\n".join(body[1:]))))
    doc_n += bool(hits)
    table_n += bool(tables)
    either += bool(hits or tables)
    print(f"  {'doc' if hits else '   '} {'table' if tables else '     '} {path} {sym}: doc->{','.join(hits) or '-'} tables->{','.join(tables) or '-'}")
print(f"{rows} declared surfaces: {doc_n} with a docstring/comment naming the right concept, "
      f"{table_n} touching a tbl_* table, {either} with either signal")
