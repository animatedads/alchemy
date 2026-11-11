#!/usr/bin/env python3
"""Offline, fail-closed MCP catalogue composition preflight.

Build-time Python only. The ooRexx project service remains the sole runtime
coordination and journal authority. This tool neither connects to MCP nor
modifies a live service or its JSONL journal.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

HEX64 = re.compile(r"[0-9a-f]{64}\Z")
RUNTIME_ID = re.compile(r"[A-Za-z][A-Za-z0-9_.-]*\Z")
SPHERE_ID = re.compile(r"[A-Za-z][A-Za-z0-9_.-]*\Z")
VOLATILE_FIELDS = {"ownership", "requestCount", "unreadRequestCount", "readByCaller", "answeredByCaller"}


class CatalogueRefused(ValueError):
    """A candidate must not be used for deployment."""


def _load(path: Path) -> tuple[dict, str]:
    data = path.read_bytes()
    if len(data) > 32 * 1024 * 1024:
        raise CatalogueRefused(f"input too large: {path.name}")
    try:
        obj = json.loads(data)
    except (UnicodeDecodeError, ValueError) as e:
        raise CatalogueRefused(f"not JSON: {path.name}") from e
    if not isinstance(obj, dict) or not isinstance(obj.get("components"), list):
        raise CatalogueRefused(f"missing components array: {path.name}")
    return obj, hashlib.sha256(data).hexdigest()


def _source(doc: dict, label: str) -> dict:
    artifact = doc.get("sourceArtifact")
    digest = doc.get("sourceSha256")
    if not isinstance(artifact, str) or not artifact.strip():
        raise CatalogueRefused(f"{label}: accepted sourceArtifact missing")
    if not isinstance(digest, str) or not HEX64.fullmatch(digest):
        raise CatalogueRefused(f"{label}: accepted sourceSha256 must be a lowercase SHA-256")
    return {"kind": label, "artifact": artifact, "sha256": digest}


def _aliases(row: dict, label: str) -> set[str]:
    aliases = row.get("aliases", [])
    if not isinstance(aliases, list) or any(not isinstance(x, str) or not x.strip() for x in aliases):
        raise CatalogueRefused(f"{label}: aliases must be nonempty strings")
    return set(aliases)


def _runtime_entries(doc: dict, label: str) -> tuple[list[dict], dict[str, set[str]]]:
    entries = []
    ids = {}
    for index, row in enumerate(doc["components"]):
        if not isinstance(row, dict):
            raise CatalogueRefused(f"{label}: row {index} not an object")
        component_id = row.get("componentId")
        if not isinstance(component_id, str) or not RUNTIME_ID.fullmatch(component_id):
            raise CatalogueRefused(f"{label}: invalid runtime ID at row {index}")
        if row.get("componentKind", "runtime") != "runtime":
            raise CatalogueRefused(f"{label}: non-runtime component {component_id}")
        aliases = _aliases(row, f"{label}/{component_id}")
        ids.setdefault(component_id, set()).update(aliases)
        entries.append(row)
    if not entries:
        raise CatalogueRefused(f"{label}: empty runtime list")
    return entries, ids


def _sphere_entries(doc: dict) -> tuple[list[dict], set[str]]:
    entries = []
    ids = set()
    for index, row in enumerate(doc["components"]):
        if not isinstance(row, dict):
            raise CatalogueRefused(f"spheres: row {index} not an object")
        component_id, sphere_id = row.get("componentId"), row.get("sphereId")
        if not isinstance(sphere_id, str) or not SPHERE_ID.fullmatch(sphere_id):
            raise CatalogueRefused(f"spheres: invalid sphere ID at row {index}")
        if component_id != "sphere:" + sphere_id or row.get("componentKind") != "sphere":
            raise CatalogueRefused(f"spheres: mismatched canonical identity for {sphere_id}")
        if component_id in ids:
            raise CatalogueRefused(f"spheres: duplicate canonical component {component_id}")
        _aliases(row, f"spheres/{component_id}")
        if not isinstance(row.get("sha256"), str) or not HEX64.fullmatch(row["sha256"]):
            raise CatalogueRefused(f"spheres/{component_id}: archive SHA-256 missing")
        ids.add(component_id)
        entries.append(row)
    if not entries:
        raise CatalogueRefused("spheres: empty sphere list")
    return entries, ids


def reconcile(live: dict, runtime: dict, spheres: dict, expected_live_count: int,
              live_digest: str, runtime_digest: str, sphere_digest: str) -> tuple[dict, dict]:
    """Create candidate only after proving no live runtime ID/alias is dropped."""
    live_entries, live_ids = _runtime_entries(live, "live")
    source_entries, source_ids = _runtime_entries(runtime, "runtime-source")
    sphere_entries, sphere_ids = _sphere_entries(spheres)
    if expected_live_count < 1 or len(live_entries) != expected_live_count:
        raise CatalogueRefused(
            f"live count drift: observed {len(live_entries)}, expected {expected_live_count}")
    if len(live_ids) != len(source_ids) or set(live_ids) != set(source_ids):
        missing = sorted(set(live_ids) - set(source_ids))
        unexpected = sorted(set(source_ids) - set(live_ids))
        raise CatalogueRefused(
            f"runtime ID set differs: missing={missing[:10]} unexpected={unexpected[:10]}")
    alias_regressions = {
        key: sorted(aliases - source_ids[key])
        for key, aliases in live_ids.items()
        if aliases - source_ids[key]
    }
    if alias_regressions:
        raise CatalogueRefused(f"runtime aliases lost: {alias_regressions}")
    if any("ownership" in row or "requestCount" in row or "unreadRequestCount" in row
           for row in source_entries):
        raise CatalogueRefused("runtime source contains volatile live ownership/receipt state")
    if sphere_ids.intersection(source_ids):
        raise CatalogueRefused("cross-kind canonical component collision")
    src_runtime = _source(runtime, "api-rollup")
    src_spheres = _source(spheres, "sphere-rollup")
    candidate = {
        "schema": "oorexx.mcp.component.catalog/2",
        "sourceArtifact": src_runtime["artifact"],
        "sourceSha256": src_runtime["sha256"],
        "sources": [src_runtime, src_spheres],
        "components": source_entries + sphere_entries,
    }
    report = {
        "schema": "alchemy.mcp.catalog-reconcile-report/1",
        "status": "CANDIDATE_UNINSTALLED",
        "liveExportSha256": live_digest,
        "runtimeInputSha256": runtime_digest,
        "sphereInputSha256": sphere_digest,
        "expectedLiveRuntimeEntries": expected_live_count,
        "preservedRuntimeEntries": len(source_entries),
        "preservedRuntimeUniqueIds": len(source_ids),
        "admittedSphereEntries": len(sphere_entries),
        "combinedEntries": len(candidate["components"]),
        "combinedUniqueIds": len(set(source_ids) | sphere_ids),
        "provenance": candidate["sources"],
        "runtimeAndSphereAuthoritySeparated": True,
        "journalUnchanged": True,
        "requiresOperatorDeploymentQualification": True,
    }
    return candidate, report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-export", type=Path, required=True,
                        help="Authenticated, operator-exported project.components.list snapshot")
    parser.add_argument("--runtime-source", type=Path, required=True,
                        help="Accepted runtime-only source catalogue, not an old rollup")
    parser.add_argument("--spheres", type=Path, required=True,
                        help="Accepted first-class sphere snapshot with provenance")
    parser.add_argument("--expected-live-runtime-entries", type=int, required=True,
                        help="Pinned source-observation count to reject partial/stale snapshots")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args(argv)
    if args.output.resolve() == args.report.resolve():
        raise SystemExit("REFUSED: output and report must be separate")
    for p in (args.output, args.report):
        if p.exists():
            raise SystemExit(f"REFUSED: refusing to overwrite {p}")
    try:
        live, live_sha = _load(args.live_export)
        runtime, runtime_sha = _load(args.runtime_source)
        spheres, spheres_sha = _load(args.spheres)
        result, report = reconcile(live, runtime, spheres,
                                   args.expected_live_runtime_entries,
                                   live_sha, runtime_sha, spheres_sha)
    except (OSError, CatalogueRefused) as exc:
        raise SystemExit(f"REFUSED: {exc}") from exc
    # All checks completed before writing either candidate file.
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"CANDIDATE_UNINSTALLED: {report['preservedRuntimeUniqueIds']} runtime IDs; "
          f"{report['admittedSphereEntries']} sphere components; "
          f"{report['combinedEntries']} catalogue rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
