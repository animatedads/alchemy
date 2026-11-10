#!/usr/bin/env python3
"""ALCH-SWEEP-B: offline, read-only Alchemy consumer release-contract audit.

No shell commands, network I/O, writes to inspected repository, or host probes.
Findings measure inspected source, never installation or live acceptance.
"""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_COLS = (
    "edge_id", "service", "upstream_prerequisite", "consumer_or_operation",
    "required_gate", "status", "category", "owner_lane_or_coordination",
    "evidence_url", "acceptance_proof",
)


def finding(code, status, detail, evidence=""):
    return {"code": code, "status": status, "detail": detail, "evidence": evidence}


def validate_ledger(path: Path):
    results = []
    try:
        with path.open(encoding="utf-8", newline="") as h:
            reader = csv.DictReader(h)
            if tuple(reader.fieldnames or ()) != REQUIRED_COLS:
                return [finding("LEDGER_FORMAT", "INVALID", "Unexpected CSV columns")]
            rows = list(reader)
        ids = [r["edge_id"] for r in rows]
        if len(ids) != len(set(ids)):
            results.append(finding("LEDGER_IDS", "INVALID", "Duplicate edge IDs"))
        if not rows:
            results.append(finding("LEDGER_EMPTY", "INVALID", "No dependency edges"))
        for idx, r in enumerate(rows, 2):
            for k in REQUIRED_COLS:
                if not (r.get(k) or "").strip():
                    results.append(finding("LEDGER_ROW", "INVALID", f"CSV line {idx}: missing {k}"))
            if not r.get("evidence_url", "").startswith("https://github.com/"):
                results.append(finding("LEDGER_EVIDENCE", "INVALID", f"CSV line {idx}: not a GitHub evidence URL"))
        if not results:
            results.append(finding("LEDGER", "PASS", f"{len(rows)} unique edges with required evidence fields"))
    except (OSError, UnicodeError, csv.Error) as e:
        results.append(finding("LEDGER_READ", "INVALID", f"Cannot read CSV: {e}"))
    return results


def check_unit_names(deploy: str, private: dict):
    # Inspect the case branch for each role, not arbitrary mentions elsewhere.
    try:
        section = deploy.split("required_units(){", 1)[1].split("\n}", 1)[0]
    except IndexError:
        return finding("PRIVATE_UNITS", "BLOCKED", "No required_units() body")
    mismatches = []
    for hostname, role in (("noc.rasenfalcon.com", "noc"), ("office.rasenfalcon.com", "office")):
        expected = private["instances"][hostname]["service"]
        # The file uses 'noc|public)' or 'office)' case patterns; collect that arm only.
        m = re.search(r"(?m)^\s*(?:\w+\|)*" + role + r"(?:\|\w+)*\)\s*([^;]*);;", section)
        if not m or expected not in m.group(1):
            mismatches.append(f"{role}: expected {expected} in role arm")
    return finding("PRIVATE_UNITS", "BLOCKED" if mismatches else "PASS",
                   "; ".join(mismatches) if mismatches else "NOC/Office role units match private mTLS policy")


def inspect_repo(repo: Path):
    base = repo / "packages" / "rasenfalcon_delivery_v0.4"
    result = []
    try:
        deploy = (base / "handoff/deployment/deploy.sh").read_text(encoding="utf-8")
        hostmap = json.loads((base / "handoff/deployment/HOSTS.json").read_text(encoding="utf-8"))
        private = json.loads((base / "handoff/contracts/PRIVATE_HTTPS_POLICY.json").read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as e:
        return [finding("INSTALLER_SOURCE", "BLOCKED", f"Cannot parse required Rasen Falcon source: {e}")]
    result.append(check_unit_names(deploy, private))
    # Use the declared destination allowlist, not any generic mention of timers.
    match = re.search(r"manifest_dest_ok\(\)\{(.*?)\n\}", deploy, re.S)
    timer_ok = bool(match and re.search(r"rasenfalcon-\*\.timer", match.group(1)))
    result.append(finding("TIMER_ALLOWLIST", "PASS" if timer_ok else "BLOCKED",
                          "Systemd minute ticker destination allowed" if timer_ok
                          else "No rasenfalcon-*.timer installer destination allowlist"))
    role_root = base / "release" / "roles"
    roles = ["gateway", "office", "noc", "mcp", "identity", "public"]
    absent = []
    for role in roles:
        rp = role_root / role
        for filename in ("manifest.tsv", "services.txt", "tests.tsv"):
            if not (rp / filename).is_file():
                absent.append(f"{role}/{filename}")
        if not (rp / "files").is_dir():
            absent.append(f"{role}/files")
    result.append(finding("RELEASE_ROLES", "BLOCKED" if absent else "PASS",
                          f"Missing {len(absent)} role payload elements" if absent
                          else "All expected role payload element paths exist"))
    # Check whether actual role-specific units are shipped, not just named in JSON.
    found_units = [p.name for p in base.rglob("*.service") if p.is_file()]
    required_units = [v["service"] for v in private["instances"].values()]
    missing_units = [u for u in required_units if u not in found_units]
    result.append(finding("PRIVATE_UNIT_FILES", "BLOCKED" if missing_units else "PASS",
                          f"Missing unit sources: {', '.join(missing_units)}" if missing_units
                          else "Private NOC/Office unit sources present"))
    qpath = repo / "packages/oorexx_queue_fabric_v0.9-dev6/integration.json"
    try:
        q = json.loads(qpath.read_text(encoding="utf-8"))
        decl = q["environment"]
        roots = [(k, decl["set"][k]) for k in decl["require_dirs"]]
        missing = []
        for key, value in roots:
            prefix = "${REPO_ROOT}/"
            if not value.startswith(prefix):
                missing.append(f"{key}: not a repo-relative requirement")
            elif not (repo / value[len(prefix):]).is_dir():
                missing.append(value[len(prefix):])
        result.append(finding("QUEUE_REQUIRED_DIRS", "BLOCKED" if missing else "PASS",
                              f"{len(missing)}/{len(roots)} declared required source paths absent: " + ", ".join(missing)
                              if missing else f"All {len(roots)} required source directories exist"))
    except (OSError, KeyError, TypeError, ValueError) as e:
        result.append(finding("QUEUE_REQUIRED_DIRS", "BLOCKED", f"Could not resolve Queue Fabric declared source paths: {e}"))
    result.append(finding("SSC_ACCEPTED_CLOSURE", "NOT_VERIFIED",
                          "Requires accepted signed/qualified external SSC deployment receipt; Git tree is not authority"))
    result.append(finding("LIVE_HOST_INSTALLATION", "NOT_OBSERVED",
                          "Deliberately no host access or service probes; not an operational status"))
    result.append(finding("HOSTMAP_CONTRACT", "PASS" if hostmap.get("separate_private_https_services", {}) else "BLOCKED",
                          "Host map defines dedicated NOC/Office HTTPS role names"))
    return result


def inspect_website_candidate(path: Path):
    try:
        lock = json.loads((path / "handoff/public_site/github_source.lock.json").read_text(encoding="utf-8"))
        files = lock["files_sha256"]
        actual_dir = path / "website"
        missing, mismatch = [], []
        for rel, expected in files.items():
            relative = Path(rel)
            if relative.is_absolute() or ".." in relative.parts:
                return [finding("WEBSITE_LOCK", "INVALID", "Unsafe path in candidate lock")]
            dest = actual_dir / relative
            if not dest.is_file():
                missing.append(rel)
            elif hashlib.sha256(dest.read_bytes()).hexdigest() != expected:
                mismatch.append(rel)
        return [finding("WEBSITE_LOCK", "BLOCKED" if missing or mismatch else "PASS",
                        f"{len(files)} locked files; missing={missing}; mismatched={mismatch}" if missing or mismatch
                        else f"{len(files)} locked files match their SHA-256 digests")]
    except (OSError, UnicodeError, KeyError, ValueError, TypeError) as e:
        return [finding("WEBSITE_LOCK", "INVALID", f"Cannot inspect candidate: {e}")]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", type=Path, help="Existing local alchemy checkout, read only")
    ap.add_argument("--website-candidate-dir", type=Path, help="Exact unpacked candidate package (website/ + handoff/)")
    ap.add_argument("--audit-only", action="store_true", help="Verify audit ledger only")
    ap.add_argument("--strict", action="store_true", help="Exit 3 if any required gate BLOCKED/NOT_VERIFIED")
    ap.add_argument("--json", action="store_true", help="Machine-readable report")
    args = ap.parse_args(argv)
    if args.audit_only and (args.repo or args.website_candidate_dir):
        ap.error("--audit-only cannot combine with --repo or --website-candidate-dir")
    checks = validate_ledger(ROOT / "docs/SERVICE_CRITICAL_PATH.csv")
    if args.repo is not None:
        checks.extend(inspect_repo(args.repo))
    if args.website_candidate_dir is not None:
        checks.extend(inspect_website_candidate(args.website_candidate_dir))
    summary = {
        "schema": "alchemy.service.activation.audit/0.1",
        "scope": "READ_ONLY_SOURCE; NO_LIVE_PROBES",
        "status": "INVALID" if any(x["status"] == "INVALID" for x in checks)
                  else "NOT_READY" if any(x["status"] in ("BLOCKED", "NOT_VERIFIED") for x in checks)
                  else "SOURCE_CHECKS_PASS_NOT_OPERATIONAL",
        "findings": checks,
    }
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        for x in checks:
            print(f"{x['status']:<13} {x['code']:<25} {x['detail']}")
        print("AUDIT STATUS:", summary["status"])
    if summary["status"] == "INVALID":
        return 2
    if args.strict and summary["status"] == "NOT_READY":
        return 3
    return 0

if __name__ == "__main__":
    sys.exit(main())
