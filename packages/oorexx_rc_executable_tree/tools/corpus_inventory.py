#!/usr/bin/env python3
"""Inventory original ooRexx Windows RC files without misreporting excerpt passes.

Run: python3 tools/corpus_inventory.py --checkout /path/to/ooRexx
Exit status 0 only if all manifest files exist with their local quoted includes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

QUOTED_INCLUDE = re.compile(r'^\s*#\s*include\s*"([^"]+)"', re.I | re.M)
RESOURCE = re.compile(
    r'^\s*(?:[A-Za-z_][\w]*|\d+)\s+'
    r'(DIALOGEX|DIALOG|MENU|MENUEX|ACCELERATORS|STRINGTABLE|'
    r'ICON|CURSOR|BITMAP|RCDATA|VERSIONINFO|MESSAGETABLE|HTML)\b',
    re.I | re.M,
)

def inventory(checkout, manifest):
    results = []
    for relative in manifest.read_text(encoding="utf-8").splitlines():
        relative = relative.strip()
        if not relative or relative.startswith("#"):
            continue
        source = checkout / relative
        record = {"path": relative, "status": "missing"}
        if source.is_file():
            data = source.read_bytes()
            text = data.decode("utf-8-sig", errors="replace")
            includes = QUOTED_INCLUDE.findall(text)
            missing = [name for name in includes if not
                       (source.parent / name.replace("\\", "/")).is_file()]
            kinds = {}
            for kind in RESOURCE.findall(text):
                k = kind.upper()
                kinds[k] = kinds.get(k, 0) + 1
            record.update({
                "status": "incomplete_includes" if missing else "present",
                "sha256": hashlib.sha256(data).hexdigest(),
                "bytes": len(data),
                "lines": len(text.splitlines()),
                "resource_kind_counts_heuristic": kinds,
                "local_includes": includes,
                "missing_local_includes": missing,
            })
        results.append(record)
    return results

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkout", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=Path(__file__).resolve().parents[1] /
                        "corpus" / "official_oodialog.txt")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    records = inventory(args.checkout, args.manifest)
    totals = {key: sum(x["status"] == key for x in records)
              for key in ("present", "missing", "incomplete_includes")}
    result = {"schema": "alchemy.rc.corpus.inventory/1",
              "note": "Inventory only; no parser or compiler compatibility proved",
              "total": len(records), "totals": totals, "files": records}
    content = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")
    return 0 if totals["present"] == len(records) and len(records) else 1

if __name__ == "__main__":
    raise SystemExit(main())
