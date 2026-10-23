#!/usr/bin/env python3
"""Static structure check, not a Gopher VALID/CLEAN claim."""
import json
from pathlib import Path
root = Path(__file__).resolve().parent.parent
def read(rel):
    return json.loads((root / rel).read_text(encoding="utf-8"))
sphere = read("packs/connect-selector/00-sphere.json")
policy = read("packs/connect-selector/01-access-policy.json")
profile = read("profiles/connect-selector.json")
ledger = read("SOURCE_ARCHIVES.json")
assert sphere["id"] == "connect-selector" and sphere["kind"] == "sphere"
assert sphere["access_policy"] == policy["id"]
assert "packs/connect-selector" in profile["packs"]
articles = {}
for f in (root / "packs/connect-selector/articles").glob("*.json"):
    data = json.loads(f.read_text(encoding="utf-8"))
    articles[data["id"]] = data
assert len(articles) == 4
assert set(sphere["start_here"]).issubset(articles)
for a in articles.values():
    assert a["sphere"] == sphere["id"] and a["kind"] == "article"
    assert set(a.get("related", [])) <= set(articles)
    for p in a["provenance"]:
        assert p["sha256"] == ledger["artifacts"][p["artifact"]]["sha256"]
corpus = read("packs/connect-selector/corpora/connect-selector.continuity.json")
assert corpus["sphere"] == sphere["id"] and len(corpus["records"]) >= 8
print("PASS: ConnectSelector Gopher sphere static structure")
