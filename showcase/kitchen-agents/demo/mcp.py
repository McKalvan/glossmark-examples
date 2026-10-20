#!/usr/bin/env python3
"""Drive `gloss mcp` over stdio the way an agent harness does: newline-delimited JSON-RPC.

The workspace is copied to a temporary directory first, because propose_concept writes
the ontology. The server runs as GLOSS_ACTOR=agent:menu-curator, so propose_link applies
that subagent's remit. Responses are trimmed for reading; --raw prints them whole.
Usage: demo/mcp.py [--raw]    (GLOSS overrides the binary)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
GLOSS = os.environ.get("GLOSS", str(HERE.parent.parent / ".tools" / "bin" / "gloss"))
RAW = "--raw" in sys.argv


def trim(name, result):
    if RAW:
        return result
    if name == "search_concepts":
        return [{k: hit[k] for k in ("curie", "kind", "aliases", "artifacts", "score", "matched") if k in hit} for hit in result]
    if name == "concepts_for_path":
        b = result["boundary"]
        return {
            "boundary": b["boundary"],
            "realizes": b["realizes"],
            "allowed": b["allowed"][:4] + ["..."],
            "links": result["links"],
        }
    if name == "impact_of":
        out = []
        for f in result["change"]["files"]:
            out.append({
                "path": f["path"],
                "boundary": f["boundary"],
                "concepts": [{k: c.get(k) for k in ("curie", "criticality", "criticality_from", "tests")} for c in f["concepts"]],
                **{k: f[k] for k in ("criticality", "hint") if k in f},
            })
        return out
    return result


MENU_CURATOR_CALLS = [
    ("search_concepts", {"query": "chit"}),
    ("search_concepts", {"query": "allergy check", "limit": 2}),
    ("concepts_for_path", {"path": "api/ordering/services/allergen_guard.py"}),
    ("propose_link", {"path": "api/ordering/services/menu_catalog.py", "relation": "implements",
                      "target": ".MenuCatalog", "conf": 0.88}),
    ("propose_link", {"path": "api/ordering/services/order_flow.py", "relation": "implements",
                      "target": ".OrderFlow", "conf": 0.9}),
    ("propose_concept", {"curie": "pepper:SplitBill", "kind": "process", "realizes": ["dine:Checkout"],
                         "doc": "Splitting one bill into several payments at the table."}),
    ("impact_of", {"paths": ["api/ordering/services/allergen_guard.py"]}),
]
# Inside this agent's remit, on the critical allergen rule: propose_link says SOFT, gloss diff says HARD.
ALLERGEN_AUDITOR_CALLS = [
    ("propose_link", {"path": "api/tests/test_allergen_guard.py", "relation": "verifies",
                      "target": "dine:AllergenRule", "conf": 0.95}),
]


def session(ws, actor, calls, opening=False):
    """One MCP server process; GLOSS_ACTOR is fixed for its lifetime, as in .mcp.json."""
    env = dict(os.environ, GLOSS_ACTOR=actor)
    server = subprocess.Popen([GLOSS, "mcp"], cwd=ws, env=env, text=True,
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    next_id = 0

    def send(method, params=None, notify=False):
        nonlocal next_id
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            next_id += 1
            msg["id"] = next_id
        server.stdin.write(json.dumps(msg) + "\n")
        server.stdin.flush()
        return None if notify else json.loads(server.stdout.readline())

    print(f"\n### gloss mcp with GLOSS_ACTOR={actor}")
    init = send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                               "clientInfo": {"name": "kitchen-agents-demo", "version": "1"}})
    send("notifications/initialized", notify=True)
    if opening:
        print("→ initialize")
        print("← serverInfo", json.dumps(init["result"]["serverInfo"]), "| instructions:",
              init["result"]["instructions"][:160] + "...")
        tools = send("tools/list")["result"]["tools"]
        print("\n→ tools/list")
        print("←", ", ".join(t["name"] for t in tools))
    for name, args in calls:
        reply = send("tools/call", {"name": name, "arguments": args})
        print(f"\n→ tools/call {name} {json.dumps(args)}")
        if "error" in reply:
            print("← error", json.dumps(reply["error"]))
            continue
        result = reply["result"].get("structuredContent")
        print("←", json.dumps(trim(name, result), indent=None if name != "concepts_for_path" else 1))
    server.stdin.close()
    server.wait(timeout=10)


def main():
    tmp = Path(tempfile.mkdtemp())
    try:
        ws = tmp / "ws"
        shutil.copytree(HERE, ws)
        session(ws, "agent:menu-curator", MENU_CURATOR_CALLS, opening=True)
        session(ws, "agent:allergen-auditor", ALLERGEN_AUDITOR_CALLS)

        entry = (ws / "ontology" / "pepper.gloss.yaml").read_text().split("  SplitBill:")[1]
        print("\n$ sed -n '/SplitBill:/,$p' ontology/pepper.gloss.yaml   # what propose_concept wrote")
        print("  SplitBill:" + entry.rstrip())
        marker = [l for l in (ws / "api/ordering/services/payment_handoff.py").read_text().splitlines() if "SplitBill" in l]
        print("$ grep SplitBill api/ordering/services/payment_handoff.py   # the NEW: marker it rewrote")
        print(marker[0])
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
