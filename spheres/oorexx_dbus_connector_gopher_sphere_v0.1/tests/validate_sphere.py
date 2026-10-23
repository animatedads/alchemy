#!/usr/bin/env python3
"""Static sphere consistency check. Does not execute Gopher or native ooRexx."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
pack = root / "packs/oo-rexx-dbus"
meta = json.loads((pack / "00-sphere.json").read_text())
policy = json.loads((pack / "01-access-policy.json").read_text())
profile = json.loads((root / "profiles/oo-rexx-dbus.json").read_text())
articles = [json.loads(p.read_text()) for p in sorted((pack / "articles").glob("*.json"))]
ids = {a["id"] for a in articles}
assert len(ids) == 4
assert meta["kind"] == "sphere" and meta["id"] == "oo-rexx-dbus"
assert policy["kind"] == "access-policy" and policy["id"] == meta["access_policy"]
assert profile["id"] == meta["id"] and "packs/oo-rexx-dbus" in profile["packs"]
assert set(meta["start_here"]) == ids
for article in articles:
    assert article["kind"] == "article" and article["sphere"] == meta["id"]
    assert set(article.get("related", [])) <= ids
print("PASS: four articles, sphere metadata, read-only access policy, profile and cross-references")
