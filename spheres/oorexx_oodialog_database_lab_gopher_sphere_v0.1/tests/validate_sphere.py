#!/usr/bin/env python3
"""Offline SHA-256 and schema-envelope validation of Database Lab sphere."""
import hashlib
import json
import re
import sys
from pathlib import Path


def validate(root):
    manifest = root / "qualification/MANIFEST.sha256"
    listed = {}
    for row in manifest.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", row)
        if not match or match[2] in listed:
            raise ValueError("invalid or duplicate manifest entry: " + row)
        listed[match[2]] = match[1]
    actual = {p.relative_to(root).as_posix() for p in root.rglob("*")
              if p.is_file() and p != manifest and "__pycache__" not in p.parts}
    if set(listed) != actual:
        raise ValueError(f"manifest missing={sorted(actual - set(listed))} stale={sorted(set(listed) - actual)}")
    for name, sha in listed.items():
        if hashlib.sha256((root / name).read_bytes()).hexdigest() != sha:
            raise ValueError("digest mismatch: " + name)
    for path in root.rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
    pack = root / "packs/oodialog-database-lab"
    sphere = json.loads((pack / "00-sphere.json").read_text(encoding="utf-8"))
    if sphere["id"] != "oodialog-database-lab":
        raise ValueError("invalid sphere ID")
    articles = {}
    for path in (pack / "articles").glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        if data["kind"] != "article" or data["sphere"] != sphere["id"] or data["id"] != path.stem:
            raise ValueError("article envelope mismatch: " + path.name)
        articles[path.stem] = data
    if any(name not in articles for name in sphere["start_here"]):
        raise ValueError("missing start article")
    print(f"PASS oodialog-database-lab sphere: {len(articles)} articles, {len(listed)} checked members")


if __name__ == "__main__":
    try:
        validate(Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve())
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as error:
        print("FAIL oodialog-database-lab sphere: " + str(error), file=sys.stderr)
        sys.exit(1)
