#!/usr/bin/env python3
"""Qualification check for the reference-only Civic iXBRL projection tool."""
from __future__ import annotations
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "fixtures/companies_house/16024067_aa_2026-07-17.xhtml"
EXPECTED = ROOT / "fixtures/companies_house/16024067_aa_2026-07-17.projection.json"
TOOL = ROOT / "tools/reference_civic_ixbrl_projection.py"

with tempfile.TemporaryDirectory() as td:
    actual_path = Path(td) / "projection.json"
    subprocess.run([sys.executable, str(TOOL), str(SOURCE), str(actual_path)], check=True, stdout=subprocess.DEVNULL)
    expected_bytes = EXPECTED.read_bytes()
    actual_bytes = actual_path.read_bytes()
    assert actual_bytes == expected_bytes, "reference projection is not deterministic"

p = json.loads(EXPECTED.read_text(encoding="utf-8"))
body = SOURCE.read_bytes()
assert p["body_sha512"] == hashlib.sha512(body).hexdigest()
assert p["body_sha256"] == hashlib.sha256(body).hexdigest()
assert p["company_number"] == "16024067"
assert p["company_name"] == "WALKABOUT LTD"
assert p["period_start"] == "2024-10-17"
assert p["period_end"] == "2025-10-31"
assert p["completeness"]["income_statement_delivered"] is False
assert len(p["facts"]) == 89
assert all(f["source_pointer"].startswith("ixbrl:fact-document-order[") for f in p["facts"])
print("reference projection assertions=10 failures=0")
