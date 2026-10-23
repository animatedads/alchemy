#!/usr/bin/env python3
"""Regression contract for RTO Inspector evidence truth (r141).

Run in the full r141 RTO source tree. Synthetic evidence cannot prove dispatch.
"""
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("rto_inspector_import", ROOT / "tools/rto_inspector_import.py")
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def save(folder, name, payload):
    p = folder / name
    p.write_text(json.dumps(payload), encoding="utf-8")

def test():
    fixtures = ROOT / "tests/fixtures/inspector-live"
    report = m.summarize_live(ROOT, fixtures)
    assert report["ok"]
    assert "RTOCOMMAND" in report["observed_classes"]
    assert "rto-authority-corridor" in report["receipt_stems"]
    with tempfile.TemporaryDirectory() as temp:
        p = Path(temp)
        save(p, "rto-inspector-CORE-fake.json", {
            "schema": m.SNAPSHOT_SCHEMA,
            "warning": "RTOCOMMAND RTOOPERATIONSECURITYCONTEXT",
            "objects": [{"name": "noise", "description": "RTOREX86LOWFRUITOPERATIONS"}],
        })
        result = m.summarize_live(ROOT, p)
        assert not result["observed_classes"]
        save(p, ".rto-authority-corridor.receipt.json", {
            "schema": m.RECEIPT_SCHEMA,
            "trace_request": "rto-authority-corridor.json",
            "status": "rejected", "loaded_rules": 5,
            "classes": ["RTOCOMMAND"],
        })
        result = m.summarize_live(ROOT, p)
        assert not result["ok"] and "rto-authority-corridor" not in result["receipt_stems"]
        assert not m.compare_reports(ROOT, result)["ok"]
        save(p, ".rto-authority-corridor.receipt.json", {
            "schema": m.RECEIPT_SCHEMA,
            "trace_request": "../different-request.json",
            "status": "loaded", "loaded_rules": 9,
            "classes": ["RTOCOMMAND"],
        })
        assert not m.summarize_live(ROOT, p)["ok"]
        (p / ".rto-authority-corridor.receipt.json").unlink()
        (p / "rto-inspector-CORE-fake.json").unlink()
        (p / "suspicious.json").symlink_to(fixtures / "rto-inspector-CORE-20260619T180000000000.json")
        assert not m.summarize_live(ROOT, p)["ok"]
        (p / "suspicious.json").unlink()
        save(p, ".rto-authority-corridor.receipt.json", {
            "schema": m.RECEIPT_SCHEMA,
            "trace_request": "rto-authority-corridor.json",
            "status": "loaded", "loaded_rules": 0,
            "classes": ["RTOCOMMAND"],
        })
        assert not m.summarize_live(ROOT, p)["ok"]
    absent = m.summarize_live(ROOT, ROOT / "reports/inspector/no-live")
    assert absent["ok"] and absent["live_required_to_clear_warnings"]
    assert not absent["observed_classes"]

if __name__ == "__main__":
    test()
    print("PASS r141 Inspector evidence truth")
