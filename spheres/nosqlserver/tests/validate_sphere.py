#!/usr/bin/env python3
"""Offline structural and SHA-256 validation for the NoSQLServer Gopher sphere."""
import hashlib
import json
import re
import sys
from pathlib import Path


def main(root):
    root = Path(root).resolve()
    manifest = root / "qualification/MANIFEST.sha256"
    rows = {}
    for line in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        if not match:
            raise ValueError(f"malformed manifest line: {line!r}")
        digest, name = match.groups()
        if name in rows:
            raise ValueError(f"duplicate manifest member: {name}")
        rows[name] = digest
    actual = {
        p.relative_to(root).as_posix()
        for p in root.rglob("*")
        if p.is_file() and p != manifest and "__pycache__" not in p.parts
    }
    listed = set(rows)
    if actual != listed:
        raise ValueError(f"manifest coverage missing={sorted(actual-listed)} stale={sorted(listed-actual)}")
    for name, digest in rows.items():
        observed = hashlib.sha256((root/name).read_bytes()).hexdigest()
        if observed != digest:
            raise ValueError(f"hash mismatch: {name}")
    for path in root.rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
    sphere = json.loads((root/"packs/nosqlserver/00-sphere.json").read_text(encoding="utf-8"))
    if sphere["id"] != "nosqlserver":
        raise ValueError("wrong sphere id")
    articles = {}
    for path in sorted((root/"packs/nosqlserver/articles").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("kind") != "article" or data.get("sphere") != "nosqlserver" or data.get("id") != path.stem:
            raise ValueError(f"article envelope mismatch: {path.name}")
        if path.stem in articles:
            raise ValueError(f"duplicate article: {path.stem}")
        articles[path.stem] = data
    for article_id in sphere["start_here"]:
        if article_id not in articles:
            raise ValueError(f"missing start article: {article_id}")
    publication = articles["nosqlserver.sqlite-writable-v091"]["publication"]
    if publication["sha256"] != "d4a276007029e66512611ea7e836ca7ab30209b80ac7d46ecf1fba61121f02d0":
        raise ValueError("SQLite v0.91 archive provenance changed")
    if "packages/nosqlserver_v0.79" not in publication["github_full_directory"]:
        raise ValueError("GitHub source baseline no longer described")
    print(f"PASS nosqlserver sphere SHA-256 and structure: {len(articles)} articles, {len(rows)} members")


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    except (KeyError, OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"FAIL nosqlserver sphere: {exc}", file=sys.stderr)
        sys.exit(1)
