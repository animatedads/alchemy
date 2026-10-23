#!/usr/bin/env python3
"""Read-only RTO Inspector evidence importer.

An observed class is not an executed request and a trace receipt is not an
authorization. Only structured, successful Clouseau evidence contributes to
coverage; arbitrary JSON text never does. The bridge cannot dispatch work.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, List

TRACE_DIR = Path("data/inspector-trace-requests")
DEFAULT_LIVE_DIR = Path("reports/inspector/live")
DEFAULT_OUTPUT = Path("reports/inspector/live_import_summary.json")
REGRESSION_REPORT = Path("reports/inspector/regression.json")
OPERATOR_REPORT = Path("reports/inspector/operator_status.json")
EVIDENCE_REPORT = Path("reports/inspector/evidence_summary.json")

REQUIRED_TRACE_STEMS = {
    "rto-authority-corridor", "rto-command-request-corridor",
    "rto-filesystem-observe", "rto-filesystem-observe-corridor",
}
REQUIRED_CORRIDOR_CLASSES = {
    "RTOCOMMAND", "RTOCOMMANDREGISTRY", "RTOOPERATIONREGISTRY",
    "RTOOPERATIONSECURITYCONTEXT",
}
REQUIRED_OBSERVE_CLASSES = {"RTOCHECKBROKENSYMLINKS", "RTOREX86LOWFRUITOPERATIONS"}
REQUIRED_CLASSES = REQUIRED_CORRIDOR_CLASSES | REQUIRED_OBSERVE_CLASSES
RECEIPT_SCHEMA = "alchemy.oorexx.inspector-clouseau.trace-request-receipt.v1"
LOAD_SCHEMA = "alchemy.oorexx.inspector-clouseau.trace-request-load.v1"
SNAPSHOT_SCHEMA = "alchemy.oorexx.inspector-clouseau.snapshot.v1"
SUCCESS = {"loaded", "accepted", "success"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def rel(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def iter_json_files(directory: Path) -> Iterable[Path]:
    if not directory.exists() or not directory.is_dir():
        return []
    # Do not follow linked directories, nor trust a linked evidence file.
    return sorted(p for p in directory.rglob("*.json") if p.is_file() or p.is_symlink())


def classify_file(path: Path) -> str:
    name = path.name.lower()
    if name.endswith(".receipt.json"):
        return "receipt"
    if "trace-request-loaded" in name or "trace_request_load" in name:
        return "trace_request_load"
    if "handcuffs" in name or "security" in name:
        return "handcuff"
    if "unknown" in name:
        return "unknown_method"
    if "inspector" in name and any(x in name for x in ("core", "swing", "rto")):
        return "snapshot"
    return "report"


def trace_stem_from_receipt(path: Path, payload: Any) -> str:
    if isinstance(payload, dict):
        for key in ("trace_request", "request_file", "source_file", "file"):
            value = payload.get(key)
            if isinstance(value, str) and value:
                return Path(value).stem
    name = path.name.lstrip(".")
    return name.removesuffix(".receipt.json")


def structured_classes(payload: Any, kind: str) -> set[str]:
    """Recognize only explicit class slots; never search serialized report prose."""
    if not isinstance(payload, dict):
        return set()
    values: set[str] = set()
    if kind == "snapshot" and payload.get("schema") == SNAPSHOT_SCHEMA:
        for obj in payload.get("objects", []):
            if isinstance(obj, dict) and isinstance(obj.get("class"), str):
                values.add(obj["class"].upper())
    if kind in {"receipt", "trace_request_load"}:
        classes = payload.get("classes", [])
        if isinstance(classes, list):
            values.update(v.upper() for v in classes if isinstance(v, str))
    return values & REQUIRED_CLASSES


def receipt_identity(path: Path, payload: dict) -> tuple[str, str | None]:
    stem = trace_stem_from_receipt(path, payload)
    file_stem = path.name.lstrip(".").removesuffix(".receipt.json")
    if stem != file_stem or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", stem):
        return stem, "receipt file and declared request identity differ"
    return stem, None


def summarize_live(root: Path, live_dir: Path) -> Dict[str, Any]:
    live_path = live_dir if live_dir.is_absolute() else root / live_dir
    failures: List[str] = []
    warnings: List[str] = []
    files: List[Dict[str, Any]] = []
    counts: Dict[str, int] = {}
    receipt_stems: set[str] = set()
    loaded_stems: set[str] = set()
    observed_classes: set[str] = set()
    receipt_classes: set[str] = set()
    seen_receipts: set[str] = set()
    event_counts = {k: 0 for k in (
        "trace_request_events", "trace_request_load_reports", "unknown_method_events",
        "security_events", "warnings")}
    trace_files = sorted((root / TRACE_DIR).glob("*.json")) if (root / TRACE_DIR).exists() else []
    configured_stems = {p.stem for p in trace_files}
    required_existing = REQUIRED_TRACE_STEMS & configured_stems

    if not live_path.exists():
        warnings.append(f"live artefact directory does not exist yet: {rel(root, live_path)}")
    elif live_path.is_symlink() or not live_path.is_dir():
        failures.append("live evidence directory must be a real directory, not a symlink")
    else:
        for path in iter_json_files(live_path):
            kind = classify_file(path)
            counts[kind] = counts.get(kind, 0) + 1
            item: Dict[str, Any] = {"file": rel(root, path), "kind": kind, "ok": True}
            if path.is_symlink():
                item.update({"ok": False, "error": "symlink evidence refused"})
                failures.append(f"{rel(root, path)}: symlink evidence refused")
                files.append(item)
                continue
            try:
                payload = load_json(path)
            except (OSError, ValueError) as exc:
                item.update({"ok": False, "error": str(exc)})
                failures.append(f"{rel(root, path)}: invalid JSON: {exc}")
                files.append(item)
                continue
            if not isinstance(payload, dict):
                failures.append(f"{rel(root, path)}: expected JSON object")
                item.update({"ok": False, "error": "expected JSON object"})
                files.append(item)
                continue
            schema = payload.get("schema")
            item["schema"] = schema
            for key in event_counts:
                value = payload.get(key)
                if isinstance(value, (list, dict)):
                    event_counts[key] += len(value)
            classes = structured_classes(payload, kind)
            item["structured_classes"] = sorted(classes)
            if kind == "snapshot":
                if schema == SNAPSHOT_SCHEMA:
                    observed_classes.update(classes)
                else:
                    warnings.append(f"{rel(root, path)}: unrecognized snapshot schema")
            elif kind == "receipt":
                stem, err = receipt_identity(path, payload)
                status = str(payload.get("status", "")).lower()
                count = payload.get("loaded_rules", 0)
                if schema != RECEIPT_SCHEMA or err or status not in SUCCESS or type(count) is not int or count <= 0:
                    reason = err or "receipt schema/status/loaded_rules invalid"
                    item.update({"ok": False, "error": reason})
                    failures.append(f"{rel(root, path)}: {reason}")
                elif stem in seen_receipts:
                    item.update({"ok": False, "error": "duplicate receipt identity"})
                    failures.append(f"{rel(root, path)}: duplicate receipt identity {stem}")
                else:
                    seen_receipts.add(stem)
                    receipt_stems.add(stem)
                    receipt_classes.update(classes)
            elif kind == "trace_request_load":
                value = payload.get("trace_request") or payload.get("request_file")
                if schema == LOAD_SCHEMA and str(payload.get("status", "")).lower() in SUCCESS and isinstance(value, str):
                    loaded_stems.add(Path(value).stem)
                else:
                    warnings.append(f"{rel(root, path)}: trace load acknowledgement is not successful")
            files.append(item)
    if not files and live_path.exists() and not failures:
        warnings.append("live artefact directory is present but contains no JSON artefacts")

    missing_required = sorted(required_existing - receipt_stems)
    if missing_required:
        warnings.append("deterministic successful receipts not imported for required traces: " + ", ".join(missing_required))

    return {
        "schema": "alchemy.rto.inspector-live-import.v2",
        "root": str(root), "live_dir": rel(root, live_path),
        "ok": not failures, "files": files, "counts": counts,
        "receipt_stems": sorted(receipt_stems), "loaded_trace_stems": sorted(loaded_stems),
        "configured_trace_stems": sorted(configured_stems),
        "covered_classes": sorted(observed_classes | receipt_classes),
        "observed_classes": sorted(observed_classes),
        "receipt_declared_classes": sorted(receipt_classes),
        "missing_receipts_for_required_traces": missing_required,
        "event_counts": event_counts, "failures": failures, "warnings": warnings,
        "live_required_to_clear_warnings": bool(missing_required or not observed_classes or failures),
        "evidence_qualification": "STRUCTURED_REPORT_ONLY_NOT_EXECUTION_PROOF",
        "boundary_statement": "Read-only import of Inspector artefacts; no ooRexx execution or authority decisions are performed.",
    }


def compare_reports(root: Path, import_report: Dict[str, Any]) -> Dict[str, Any]:
    warnings: List[str] = []
    failures: List[str] = []
    existing_reports: Dict[str, bool] = {}
    for name, path in {
        "regression": REGRESSION_REPORT, "operator": OPERATOR_REPORT,
        "evidence": EVIDENCE_REPORT,
    }.items():
        full = root / path
        existing_reports[name] = full.exists()
        if not full.exists():
            warnings.append(f"missing static report for comparison: {path}")
            continue
        try:
            payload = load_json(full)
        except (OSError, ValueError) as exc:
            failures.append(f"{path}: invalid JSON: {exc}")
            continue
        if isinstance(payload, dict) and payload.get("ok") is False:
            failures.append(f"{path}: existing static report is not ok")

    # Only snapshot objects prove observed live classes; receipts declare hooks,
    # never method execution. Neither is an authorization to run the operation.
    live_classes = set(import_report.get("observed_classes", []))
    authority_missing_live = sorted(REQUIRED_CORRIDOR_CLASSES - live_classes)
    observe_missing_live = sorted(REQUIRED_OBSERVE_CLASSES - live_classes)
    if authority_missing_live:
        warnings.append("snapshots do not yet observe authority corridor classes: " + ", ".join(authority_missing_live))
    if observe_missing_live:
        warnings.append("snapshots do not yet observe filesystem classes: " + ", ".join(observe_missing_live))
    if not import_report.get("ok"):
        failures.append("live import rejected one or more evidence files")
    return {
        "schema": "alchemy.rto.inspector-live-compare.v2", "ok": not failures,
        "static_reports_present": existing_reports,
        "live_import_ok": bool(import_report.get("ok")),
        "authority_classes_seen_live": sorted(live_classes & REQUIRED_CORRIDOR_CLASSES),
        "observe_classes_seen_live": sorted(live_classes & REQUIRED_OBSERVE_CLASSES),
        "authority_classes_missing_live": authority_missing_live,
        "observe_classes_missing_live": observe_missing_live,
        "failures": failures, "warnings": warnings,
        "evidence_qualification": "OBSERVED_OBJECTS_NOT_DISPATCH_PROOF",
        "boundary_statement": "Comparison only; static reports and imported live artefacts are read, never executed.",
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Import and summarize live Inspector Clouseau artefacts for RTO.")
    parser.add_argument("--root", default=".")
    parser.add_argument("--live-dir", default=str(DEFAULT_LIVE_DIR))
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--compare-output", default="reports/inspector/live_compare.json")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    report = summarize_live(root, Path(args.live_dir))
    out = Path(args.output)
    if not out.is_absolute():
        out = root / out
    write_json(out, report)
    comparison = compare_reports(root, report)
    cmp_out = Path(args.compare_output)
    if not cmp_out.is_absolute():
        cmp_out = root / cmp_out
    write_json(cmp_out, comparison)
    if args.json:
        print(json.dumps({"import": report, "compare": comparison}, indent=2, sort_keys=True))
    return 0 if report["ok"] and comparison["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())