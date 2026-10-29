#!/usr/bin/env python3
"""
plan42_compatibility_matrix.py

Static Plan42 target compatibility report for one file, directory, or zip corpus.
It answers a narrower question than plan42c syntax generation:

    before I emit anything, which targets can carry this Plan42 spec natively?

Current ready target profiles are python3, bash, classicrexx/regina, oorexx, and c.  Registered future targets
still appear through plan42c --list-targets; they can be requested explicitly when
you want to see what is still blocked or library-required.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

DEFAULT_TARGETS = ("python3", "bash", "classicrexx", "oorexx", "c")


def load_plan42c(path: Path):
    spec = importlib.util.spec_from_file_location("plan42c_module", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import plan42c from {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["plan42c_module"] = module
    spec.loader.exec_module(module)
    return module


def load_specs(input_path: Path, workdir: Path) -> list[Path]:
    if input_path.is_file() and input_path.suffix.lower() == ".zip":
        extract = workdir / "extracted"
        extract.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(input_path, "r") as zf:
            zf.extractall(extract)
        return sorted(p for p in extract.rglob("*.json") if p.is_file())
    if input_path.is_dir():
        return sorted(p for p in input_path.rglob("*.json") if p.is_file())
    return [input_path]


def compact_issues(matrix: dict[str, Any], *, max_issues: int) -> dict[str, Any]:
    clone = json.loads(json.dumps(matrix))
    for result in clone.get("results", []):
        issues = result.get("issues", [])
        result["issue_count"] = len(issues)
        result["issues"] = issues[:max_issues]
        if len(issues) > max_issues:
            result["issues_truncated"] = len(issues) - max_issues
    return clone


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    summary: dict[str, dict[str, Any]] = {}
    top_kinds: dict[str, dict[str, int]] = {}
    for row in rows:
        for target, bucket in row.get("summary", {}).items():
            out = summary.setdefault(target, {
                "items": 0,
                "native": 0,
                "degraded_but_reversible": 0,
                "unsupported_nodes_preserved": 0,
                "runtime_unresolved": 0,
                "issue_total": 0,
                "unresolved_impl_total": 0,
                "unsupported_node_total": 0,
            })
            out["items"] += 1
            status = bucket.get("status", "unknown")
            if status in out:
                out[status] += 1
            else:
                out.setdefault("unknown", 0)
                out["unknown"] += 1
            out["issue_total"] += int(bucket.get("issues", 0) or 0)
            out["unresolved_impl_total"] += int(bucket.get("unresolved_impls", 0) or 0)
            out["unsupported_node_total"] += int(bucket.get("unsupported_nodes", 0) or 0)
        for result in row.get("results", []):
            target = result.get("target", "unknown")
            tk = top_kinds.setdefault(target, {})
            for kind, count in result.get("by_kind", {}).items():
                tk[kind] = tk.get(kind, 0) + int(count or 0)
    return {
        "by_target": summary,
        "issue_kinds_by_target": {t: dict(sorted(k.items(), key=lambda kv: (-kv[1], kv[0]))) for t, k in top_kinds.items()},
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build a static Plan42 target compatibility matrix.")
    parser.add_argument("input", help="Plan42 JSON file, directory, or zip corpus")
    parser.add_argument("--plan42c", default="plan42c.py", help="Path to plan42c.py")
    parser.add_argument("--targets", default=",".join(DEFAULT_TARGETS), help="Comma-separated targets; default python3,bash,classicrexx,oorexx,c")
    parser.add_argument("--max-issues", type=int, default=25, help="Maximum issues retained per target/file in report; default 25")
    parser.add_argument("--full-issues", action="store_true", help="Do not truncate per-file issue lists")
    parser.add_argument("--max-spec-bytes", type=int, default=0, help="Skip specs larger than this many bytes; 0 means no limit")
    parser.add_argument("-o", "--output", help="JSON output path; defaults to stdout")
    args = parser.parse_args(argv)

    plan42c = load_plan42c(Path(args.plan42c))
    targets = [plan42c.normalise_target(t.strip()) for t in args.targets.split(",") if t.strip()]
    rows: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    with tempfile.TemporaryDirectory(prefix="plan42_compat_") as td:
        specs = load_specs(Path(args.input), Path(td))
        for spec_path in specs:
            size = spec_path.stat().st_size
            if args.max_spec_bytes and size > args.max_spec_bytes:
                skipped.append({"spec": str(spec_path), "size_bytes": size, "reason": f"larger than --max-spec-bytes={args.max_spec_bytes}"})
                continue
            try:
                program = plan42c.Plan42Program(plan42c.read_json(spec_path))
                matrix = plan42c.compatibility_report(program, targets)
                matrix["spec_path"] = str(spec_path)
                matrix["spec_size_bytes"] = size
                if not args.full_issues:
                    matrix = compact_issues(matrix, max_issues=args.max_issues)
                rows.append(matrix)
            except Exception as exc:
                rows.append({
                    "spec_path": str(spec_path),
                    "spec_size_bytes": size,
                    "error": str(exc),
                    "summary": {},
                    "results": [],
                })
    report = {
        "schema": "plan42.compatibility_corpus_report.v1",
        "input": str(args.input),
        "plan42c": str(args.plan42c),
        "targets": targets,
        "spec_count": len(rows) + len(skipped),
        "processed_spec_count": len(rows),
        "skipped_spec_count": len(skipped),
        "skipped_specs": skipped,
        "summary": summarize(rows),
        "items": rows,
    }
    text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 1 if any("error" in row for row in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
