import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
rows=[json.loads(x) for x in p.read_text().splitlines() if x.strip()]
assert rows
assert all(r.get("zeroModelCost") is True for r in rows)
assert all(r.get("status") == "PASS" for r in rows)
assert {"WORKSPACE_CHECK","FRAMEWORK_QUALIFICATION","SOURCE_GRAPH_REFRESH","DOCUMENTATION_QUEUE_REFRESH"} <= {r["task"] for r in rows}
print(f"PASS test_autotask_ledger events={len(rows)}")
