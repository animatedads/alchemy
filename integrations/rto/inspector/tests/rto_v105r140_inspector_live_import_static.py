#!/usr/bin/env python3
"""Static acceptance for r140 Inspector live artefact import."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run_json(args):
    proc = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    if proc.returncode != 0:
        print(proc.stdout)
        print(proc.stderr, file=sys.stderr)
        raise SystemExit(proc.returncode)
    return json.loads(proc.stdout)


def main() -> int:
    required = [
        "tools/rto_inspector_import.py",
        "specs/plan42/rto_inspector_live_import.spec.json",
        "docs/plan42/INSPECTOR_LIVE_IMPORT.md",
        "tests/fixtures/inspector-live/.rto-authority-corridor.receipt.json",
        "tests/fixtures/inspector-live/rto-inspector-CORE-20260619T180000000000.json",
    ]
    missing = [p for p in required if not (ROOT / p).exists()]
    if missing:
        print("missing r140 files: " + ", ".join(missing), file=sys.stderr)
        return 1

    payload = run_json([
        sys.executable,
        "tools/rto_inspector_import.py",
        "--root", ".",
        "--live-dir", "tests/fixtures/inspector-live",
        "--output", "reports/inspector/live_fixture_import_summary.json",
        "--compare-output", "reports/inspector/live_fixture_compare.json",
        "--json",
    ])
    report = payload.get("import", {})
    compare = payload.get("compare", {})
    if not report.get("ok") or not compare.get("ok"):
        print(json.dumps(payload, indent=2), file=sys.stderr)
        return 1

    text = json.dumps(payload).upper()
    for token in [
        "RTOCOMMAND",
        "RTOCOMMANDREGISTRY",
        "RTOOPERATIONREGISTRY",
        "RTOOPERATIONSECURITYCONTEXT",
        "RTOCHECKBROKENSYMLINKS",
        "RTOREX86LOWFRUITOPERATIONS",
    ]:
        if token not in text:
            print(f"missing live import token: {token}", file=sys.stderr)
            return 1

    stems = set(report.get("receipt_stems", []))
    if "rto-authority-corridor" not in stems or "rto-filesystem-observe" not in stems:
        print("fixture receipts were not detected", file=sys.stderr)
        return 1

    default_payload = run_json([
        sys.executable,
        "tools/rto_inspector_import.py",
        "--root", ".",
        "--output", "reports/inspector/live_import_summary.json",
        "--compare-output", "reports/inspector/live_compare.json",
        "--json",
    ])
    if not default_payload.get("import", {}).get("ok"):
        print("default no-live import should remain ok with warnings", file=sys.stderr)
        return 1
    if "authority decisions" not in (ROOT / "tools/rto_inspector_import.py").read_text(encoding="utf-8"):
        print("boundary statement missing from import tool", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())