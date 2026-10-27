#!/usr/bin/env python3
"""
plan42_portability_report.py

Compile a Plan42 corpus to one or more target backends and report both syntax
survivability and semantic portability.  A syntax pass only means the generated
program parses; the diagnostics from plan42c.py say whether the target is native
or whether Plan42 had to preserve/degrade host-language fragments.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

READY_TARGETS = ("python3", "bash")


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


def safe_stem(path: Path, index: int) -> str:
    base = "_".join(path.with_suffix("").parts[-5:])
    cleaned = "".join(ch if ch.isalnum() or ch in "._-" else "_" for ch in base)
    return f"{index:04d}_{cleaned[:120]}"


def syntax_check(target: str, generated: Path) -> dict[str, Any]:
    if target == "python3":
        cmd = [sys.executable, "-m", "py_compile", str(generated)]
    elif target == "bash":
        cmd = ["bash", "-n", str(generated)]
    else:
        return {"checked": False, "ok": None, "message": "no syntax checker configured"}
    proc = subprocess.run(cmd, text=True, capture_output=True)
    return {"checked": True, "ok": proc.returncode == 0, "rc": proc.returncode, "message": (proc.stderr or proc.stdout).strip()}


def run_one(plan42c: Path, spec: Path, target: str, outdir: Path, index: int, *, timeout: int) -> dict[str, Any]:
    ext = ".py" if target == "python3" else ".sh"
    stem = safe_stem(spec, index)
    generated = outdir / f"{stem}.{target}{ext}"
    diag = outdir / f"{stem}.{target}.diagnostics.json"
    cmd = [sys.executable, str(plan42c), str(spec), "--target", target, "-o", str(generated), "--diagnostics", str(diag)]
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        return {
            "target": target,
            "compile_rc": None,
            "compile_ok": False,
            "generated": str(generated),
            "diagnostics": str(diag),
            "stderr": f"compile timeout after {timeout}s",
            "stdout": (exc.stdout or "") if isinstance(exc.stdout, str) else "",
            "syntax": {"checked": False, "ok": False, "message": "compile timeout"},
            "portability_status": "compile_timeout",
            "loss_counts": {},
            "unresolved_impls": [],
        }
    diagnostics: dict[str, Any] = {}
    if diag.exists():
        try:
            diagnostics = json.loads(diag.read_text(encoding="utf-8"))
        except Exception as exc:
            diagnostics = {"diagnostics_parse_error": str(exc)}
    syntax = syntax_check(target, generated) if generated.exists() else {"checked": False, "ok": False, "message": "generated file missing"}
    return {
        "target": target,
        "compile_rc": proc.returncode,
        "compile_ok": proc.returncode == 0,
        "generated": str(generated),
        "diagnostics": str(diag),
        "stderr": proc.stderr.strip(),
        "stdout": proc.stdout.strip(),
        "syntax": syntax,
        "portability_status": diagnostics.get("portability_status", "unknown"),
        "loss_counts": diagnostics.get("loss_counts", {}),
        "unresolved_impls": diagnostics.get("unresolved_impls", []),
    }


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    by_target: dict[str, dict[str, Any]] = {}
    for row in rows:
        target = row["target"]
        bucket = by_target.setdefault(target, {
            "items": 0,
            "compile_pass": 0,
            "syntax_pass": 0,
            "native": 0,
            "degraded_but_reversible": 0,
            "unsupported_nodes_preserved": 0,
            "runtime_unresolved": 0,
            "unknown_status": 0,
            "semantic_loss_total": 0,
            "unresolved_impl_total": 0,
        })
        bucket["items"] += 1
        if row.get("compile_ok"):
            bucket["compile_pass"] += 1
        if row.get("syntax", {}).get("ok"):
            bucket["syntax_pass"] += 1
        status = row.get("portability_status", "unknown")
        if status in bucket:
            bucket[status] += 1
        else:
            bucket["unknown_status"] += 1
        loss = row.get("loss_counts", {}) or {}
        bucket["semantic_loss_total"] += int(loss.get("total", 0) or 0)
        bucket["unresolved_impl_total"] += int(loss.get("unresolved_impls", 0) or 0)
    return by_target


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Report Plan42 target syntax and semantic portability.")
    parser.add_argument("input", help="Plan42 JSON file, directory, or zip corpus")
    parser.add_argument("--plan42c", default="plan42c.py", help="Path to plan42c.py")
    parser.add_argument("--targets", default=",".join(READY_TARGETS), help="Comma-separated targets, default python3,bash")
    parser.add_argument("--outdir", default="plan42_portability_out", help="Generated artifact directory")
    parser.add_argument("--timeout", type=int, default=60, help="Per compile timeout in seconds; default 60")
    parser.add_argument("--max-spec-bytes", type=int, default=0, help="Skip specs larger than this many bytes; 0 means no limit")
    parser.add_argument("-o", "--output", help="JSON report path; defaults to stdout")
    args = parser.parse_args(argv)

    plan42c = Path(args.plan42c)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    workdir = outdir / ".work"
    workdir.mkdir(parents=True, exist_ok=True)
    targets = [t.strip() for t in args.targets.split(",") if t.strip()]

    specs = load_specs(Path(args.input), workdir)
    rows: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []
    for idx, spec in enumerate(specs, 1):
        size = spec.stat().st_size
        if args.max_spec_bytes and size > args.max_spec_bytes:
            skipped.append({"spec": str(spec), "size_bytes": size, "reason": f"larger than --max-spec-bytes={args.max_spec_bytes}"})
            continue
        for target in targets:
            result = run_one(plan42c, spec, target, outdir, idx, timeout=args.timeout)
            result["spec"] = str(spec)
            result["spec_size_bytes"] = size
            rows.append(result)

    report = {
        "schema": "plan42.portability_report.v1",
        "input": str(args.input),
        "plan42c": str(plan42c),
        "targets": targets,
        "spec_count": len(specs),
        "processed_spec_count": len({r["spec"] for r in rows}),
        "skipped_spec_count": len(skipped),
        "skipped_specs": skipped,
        "result_count": len(rows),
        "summary": summarize(rows),
        "results": rows,
    }
    text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    failures = [r for r in rows if not r.get("compile_ok") or r.get("syntax", {}).get("ok") is False]
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
