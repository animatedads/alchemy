#!/usr/bin/env python3
"""Verify immutable raw statutory sources and text projections from source_manifest.json."""
from __future__ import annotations
import argparse
from hashlib import sha256
import json
from pathlib import Path
import sys

def verify(manifest):
    manifest = Path(manifest).resolve()
    base = manifest.parent
    obj = json.loads(manifest.read_text(encoding="utf-8"))
    issues = []
    if obj.get("errors"):
        issues.append(f"{len(obj['errors'])} upstream fetch or extraction errors")
    if not obj.get("complete"):
        issues.append("acquisition manifest marked incomplete")
    if not obj.get("files"):
        issues.append("no retrieved source files")
    for src in obj.get("files", []):
        for path_key, sha_key in (("raw_path","raw_sha256"),
                                   ("text_path","text_sha256")):
            rel = src.get(path_key, "")
            fp = (base / rel).resolve()
            try:
                fp.relative_to(base)
                if not fp.is_file():
                    raise ValueError("not a file")
                raw = fp.read_bytes()
                if not raw or sha256(raw).hexdigest()!=src.get(sha_key):
                    raise ValueError("digest mismatch or empty source")
                if path_key=="raw_path" and len(raw)!=src.get("byte_count"):
                    raise ValueError("raw byte-count mismatch")
            except Exception as exc:
                issues.append(f"{src.get('code')} {path_key}: {exc}")
        if src.get("section_text_verified") is not False:
            issues.append(f"{src.get('code')}: inconsistent section review state")
    print("SOURCES",len(obj.get("files",[])),"ERRORS",len(issues))
    for issue in issues:
        print("FAIL",issue,file=sys.stderr)
    if not issues:
        print("PASS BYTE-EXACT SOURCE AND TEXT DIGESTS")
        print("PROVISION-BOUNDARY / AS-AT-LAW CHECKS: NOT YET QUALIFIED")
    return 1 if issues else 0

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--manifest",required=True)
    sys.exit(verify(parser.parse_args().manifest))
