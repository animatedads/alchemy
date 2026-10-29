#!/usr/bin/env python3
"""Verify historical Windows RC development archives against an explicit manifest.

Never count archive presence as source-qualified upstream corpus or compiler pass.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

REQUIRED = {
    "v9": ("oorexx_executable_ui_tree_v9.zip",
           ["RcExecutableTree.cls", "test.rex", "test_append.rex", "test_reject.rex"]),
    "v10": ("oorexx_rc_windows_first_v10.zip",
            ["RcExecutableTree.cls", "RcRendererProjection.cls", "test_projection.rex"]),
    "v11": ("oorexx_windows_rc_v11.zip",
            ["rc_to_json_v11.rex", "test_v11.py"]),
    "v12": ("oorexx_windows_rc_corpus_v12.zip",
            ["corpus_runner.py", "base/rc_to_json_v11.rex"]),
    "v13": ("oorexx_windows_rc_source_gate_v13.zip",
            ["source_gate.py", "test_gate.py"]),
    "v14": ("oorexx_windows_rc_qualification_v14.zip",
            ["semantic_audit.py", "source_gate.py", "base/rc_to_json_v11.rex"]),
}

def inspect(folder):
    versions = {}
    for version, (filename, required) in REQUIRED.items():
        archive = folder / filename
        result = {"name": filename, "present": archive.is_file(),
                  "required": required}
        if archive.is_file():
            blob = archive.read_bytes()
            result["sha256"] = hashlib.sha256(blob).hexdigest()
            result["bytes"] = len(blob)
            try:
                with zipfile.ZipFile(archive) as z:
                    members = {i.filename for i in z.infolist() if not i.is_dir()}
                    corrupt = z.testzip()
                result["missing_members"] = [x for x in required if x not in members]
                result["bad_member"] = corrupt
                result["ok"] = corrupt is None and not result["missing_members"]
            except (zipfile.BadZipFile, OSError) as exc:
                result["ok"] = False
                result["error"] = str(exc)
        else:
            result["ok"] = False
        versions[version] = result
    return {"schema": "alchemy.rc.historical-archive-evidence/1",
            "qualification": "archive-integrity-only; not compiler/semantic compatibility",
            "all_verified": all(v["ok"] for v in versions.values()),
            "versions": versions}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = inspect(args.directory)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0 if report["all_verified"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
