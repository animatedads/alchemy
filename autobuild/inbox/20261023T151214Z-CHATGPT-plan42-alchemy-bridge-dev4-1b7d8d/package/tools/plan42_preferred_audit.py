#!/usr/bin/env python3
"""Audit Plan42 preferred capability usage and target availability."""
from __future__ import annotations

import argparse
import json
import sys
import zipfile
from pathlib import Path
from typing import Any, Iterable

# Keep this registry deliberately aligned with plan42c.py's first preferred drop.
STATUS_SEVERITY = {
    "native": "none",
    "emit_time": "none",
    "framework_native": "none",
    "runtime_helper": "low",
    "fallback": "low",
    "framework_candidate": "medium",
    "library_required": "medium",
    "degraded": "medium",
    "pending_yaml_cls": "medium",
    "refused": "high",
    "unknown": "high",
}

BACKENDS = {
    "preferred.log.": {"python3":"native", "oorexx":"framework_native", "classicrexx":"fallback", "regina":"fallback", "bash":"fallback", "c":"runtime_helper", "rust":"fallback"},
    "preferred.cli.": {"python3":"emit_time", "oorexx":"emit_time", "classicrexx":"emit_time", "regina":"emit_time", "bash":"emit_time", "c":"emit_time", "rust":"emit_time"},
    "preferred.json.": {"python3":"native", "oorexx":"framework_native", "classicrexx":"runtime_helper", "regina":"runtime_helper", "bash":"runtime_helper", "c":"runtime_helper", "rust":"library_required"},
    "preferred.api.adapter": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.request": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.get": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.post": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.paginate": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.auth.bearer": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.api.validate_request": {"python3":"native", "oorexx":"framework_candidate", "classicrexx":"degraded", "regina":"degraded", "bash":"degraded", "c":"runtime_helper", "rust":"library_required"},
    "preferred.api.validate_response": {"python3":"native", "oorexx":"framework_candidate", "classicrexx":"degraded", "regina":"degraded", "bash":"degraded", "c":"runtime_helper", "rust":"library_required"},
    "preferred.api.map_error": {"python3":"runtime_helper", "oorexx":"framework_candidate", "classicrexx":"degraded", "regina":"degraded", "bash":"degraded", "c":"runtime_helper", "rust":"library_required"},
    "preferred.api.audit_call": {"python3":"native", "oorexx":"framework_native", "classicrexx":"fallback", "regina":"fallback", "bash":"fallback", "c":"runtime_helper", "rust":"fallback"},
    "preferred.tsv.": {"python3":"native", "oorexx":"framework_candidate", "classicrexx":"runtime_helper", "regina":"runtime_helper", "bash":"runtime_helper", "c":"runtime_helper", "rust":"library_required"},
    "preferred.math.": {"python3":"native", "oorexx":"native", "classicrexx":"native", "regina":"native", "bash":"native", "c":"runtime_helper", "rust":"native"},
    "preferred.string.": {"python3":"native", "oorexx":"native", "classicrexx":"native", "regina":"native", "bash":"native", "c":"runtime_helper", "rust":"native"},
    "preferred.time.": {"python3":"native", "oorexx":"framework_candidate", "classicrexx":"runtime_helper", "regina":"runtime_helper", "bash":"runtime_helper", "c":"runtime_helper", "rust":"native"},
    "preferred.yaml.": {"python3":"library_required", "oorexx":"pending_yaml_cls", "classicrexx":"refused", "regina":"refused", "bash":"degraded", "c":"refused", "rust":"library_required"},
    "preferred.crypto.": {"python3":"library_required", "oorexx":"framework_native", "classicrexx":"refused", "regina":"refused", "bash":"refused", "c":"runtime_helper", "rust":"library_required"},
}

ALIASES = {"python":"python3", "py":"python3", "rexx":"regina", "classicrexx":"classicrexx", "classic-rexx":"classicrexx", "classic_rexx":"classicrexx", "sh":"bash", "c11":"c", "oo-rexx":"oorexx", "oo_rexx":"oorexx", "orx":"oorexx"}

def norm_target(t: str) -> str:
    t = t.lower().strip()
    return ALIASES.get(t, t)

def status_for(name: str, target: str) -> str:
    t = norm_target(target)
    if name in BACKENDS:
        return BACKENDS[name].get(t, "unknown")
    matches = [k for k in BACKENDS if k.endswith(".") and name.startswith(k)]
    if matches:
        return BACKENDS[max(matches, key=len)].get(t, "unknown")
    return "unknown"

def walk(value: Any, path: str = "$") -> Iterable[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        if isinstance(value.get("op"), str):
            yield path, value
        for k, v in value.items():
            if isinstance(v, (dict, list)):
                yield from walk(v, f"{path}.{k}")
    elif isinstance(value, list):
        for i, item in enumerate(value):
            yield from walk(item, f"{path}[{i}]")

def declared_preferreds(spec: dict[str, Any]) -> list[dict[str, Any]]:
    raw = spec.get("preferreds", spec.get("preferred_capabilities", []))
    out: list[dict[str, Any]] = []
    if isinstance(raw, dict):
        for k, v in raw.items():
            if str(k).startswith("preferred."):
                required = bool(v.get("required", False)) if isinstance(v, dict) else False
                out.append({"name": str(k), "required": required})
            elif isinstance(v, dict) and str(v.get("name", "")).startswith("preferred."):
                out.append({"name": str(v["name"]), "required": bool(v.get("required", False))})
    elif isinstance(raw, list):
        for item in raw:
            if isinstance(item, str) and item.startswith("preferred."):
                out.append({"name": item, "required": False})
            elif isinstance(item, dict) and str(item.get("name", "")).startswith("preferred."):
                out.append({"name": str(item["name"]), "required": bool(item.get("required", False))})
    seen = set()
    dedup = []
    for item in out:
        key = item["name"]
        if key not in seen:
            seen.add(key)
            dedup.append(item)
    return dedup

def used_preferreds(spec: dict[str, Any]) -> list[dict[str, Any]]:
    out = []
    for path, node in walk(spec):
        if str(node.get("op", "")).lower() == "impl_use":
            name = str(node.get("name", ""))
            if name.startswith("preferred."):
                out.append({"name": name, "path": path, "source": "impl_use", "required": True})
    for item in declared_preferreds(spec):
        out.append({"name": item["name"], "path": "$.preferreds", "source": "declaration", "required": item.get("required", False)})
    seen = set()
    dedup = []
    for item in out:
        key = (item["name"], item["path"], item["source"], bool(item.get("required", False)))
        if key not in seen:
            seen.add(key)
            dedup.append(item)
    return dedup

def read_specs(path: Path) -> list[tuple[str, dict[str, Any]]]:
    if path.is_file() and path.suffix == ".zip":
        specs = []
        with zipfile.ZipFile(path) as zf:
            for name in zf.namelist():
                if name.endswith(".json") or name.endswith(".plan42") or name.endswith(".plan42.json"):
                    try:
                        data = json.loads(zf.read(name).decode("utf-8"))
                    except Exception:
                        continue
                    if isinstance(data, dict) and "nodes" in data:
                        specs.append((name, data))
        return specs
    if path.is_dir():
        specs = []
        for file in sorted(path.rglob("*.json")):
            try:
                data = json.loads(file.read_text(encoding="utf-8"))
            except Exception:
                continue
            if isinstance(data, dict) and "nodes" in data:
                specs.append((str(file), data))
        return specs
    data = json.loads(path.read_text(encoding="utf-8"))
    return [(str(path), data)]

def audit(path: Path, targets: list[str]) -> dict[str, Any]:
    specs = read_specs(path)
    files = []
    totals = {"preferred_uses": 0, "high": 0, "optional_high": 0, "medium": 0, "low": 0, "none": 0, "unknown": 0}
    for filename, spec in specs:
        uses = used_preferreds(spec)
        rows = []
        for use in uses:
            target_rows = []
            for t in targets:
                st = status_for(use["name"], t)
                sev = STATUS_SEVERITY.get(st, "high")
                if sev == "high" and not bool(use.get("required", True)):
                    totals["optional_high"] += 1
                else:
                    totals[sev if sev in totals else "unknown"] += 1
                target_rows.append({"target": t, "status": st, "severity": sev})
            rows.append({**use, "targets": target_rows})
        totals["preferred_uses"] += len(uses)
        files.append({"file": filename, "module": spec.get("module"), "preferreds": rows})
    status = "pass"
    if totals["high"]:
        status = "fail"
    elif totals["medium"]:
        status = "warn"
    return {"schema": "plan42.preferred_audit.v1", "status": status, "targets": targets, "summary": totals, "files": files}

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Audit Plan42 preferred capability usage")
    ap.add_argument("input", help="Plan42 JSON file, directory, or zip")
    ap.add_argument("--targets", default="python3,oorexx,regina,bash,c,rust", help="Comma-separated targets")
    ap.add_argument("-o", "--output", help="Write report JSON")
    args = ap.parse_args(argv)
    targets = [x.strip() for x in args.targets.split(",") if x.strip()]
    report = audit(Path(args.input), targets)
    text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0 if report["status"] == "pass" else 4 if report["status"] == "warn" else 5

if __name__ == "__main__":
    raise SystemExit(main())
