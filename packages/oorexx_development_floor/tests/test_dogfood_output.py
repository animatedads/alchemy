import json, pathlib, sys
root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
graph_path = root / "state" / "source_graph.json"
hierarchy_path = root / "state" / "class_hierarchy.txt"
if not graph_path.exists():
    raise SystemExit("FAIL missing source_graph.json")
if not hierarchy_path.exists():
    raise SystemExit("FAIL missing class_hierarchy.txt")
data = json.loads(graph_path.read_text())
classes = []
methods = []
for f in data.get("files", []):
    for c in f.get("classes", []):
        classes.append(c.get("name"))
        methods.extend((c.get("name"), m.get("name")) for m in c.get("methods", []))
assert "DFSourceGraph" in classes, classes
assert ("DFSourceGraph", "writeJson") in methods, methods[:20]
assert "DFBugRecord" in classes
text = hierarchy_path.read_text()
assert "Object -> DFBugRecord" in text
print(f"PASS test_dogfood_output classes={len(classes)} methods={len(methods)}")
