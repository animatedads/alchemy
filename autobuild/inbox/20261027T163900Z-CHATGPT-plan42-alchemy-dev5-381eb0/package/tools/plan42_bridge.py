#!/usr/bin/env python3
"""Plan42 -> Alchemy capability adapter, API plan42.integration/0.1.

Transport neutral at the semantic boundary. This executable adapter is for
local trusted invocation, not for publishing a CODELET or executing generated
programs. Source and generated paths are confined to the Alchemy tree.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Any
from plan42_rx2cpp_plan import plan as native_build_plan
from plan42_rx2cpp_inventory import load_inventory as native_inventory

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "plan42c.py"
GENERATED = ROOT / "generated" / "plan42"
SCHEMA = "plan42.integration/0.1"
NATIVE_TARGETS = {"python3", "python", "py", "oorexx", "oo-rexx", "oo_rexx", "orx", "bash", "sh", "regina", "rexx", "classicrexx", "classic-rexx", "classic_rexx"}
EXTENSIONS = {"c": ".c", "c11": ".c", "rust": ".rs", "python": ".py", "python3": ".py", "py": ".py", "bash": ".sh", "sh": ".sh", "oorexx": ".rex", "oo-rexx": ".rex", "oo_rexx": ".rex", "orx": ".rex", "regina": ".rex", "rexx": ".rex", "classicrexx": ".rex", "classic-rexx": ".rex", "classic_rexx": ".rex", "cpp": ".cpp", "c++": ".cpp", "java": ".java"}


def failure(kind: str, message: str, **extra: Any) -> dict[str, Any]:
    return {"schema": SCHEMA, "ok": False, "status": kind, "message": message, **extra}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(base: Path, candidate: Path) -> bool:
    try:
        candidate.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def path_within(base: Path, name: str, *, must_exist: bool) -> Path:
    path = Path(name)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    if not inside(base, path):
        raise ValueError("path escapes the permitted Alchemy boundary")
    if must_exist and (not path.is_file() or path.is_symlink()):
        raise ValueError("required file does not exist as a regular file")
    return path


def load_spec(name: str) -> tuple[Path, dict[str, Any]]:
    path = path_within(ROOT, name, must_exist=True)
    with path.open(encoding="utf-8") as file:
        spec = json.load(file)
    if not isinstance(spec, dict) or not isinstance(spec.get("nodes"), list):
        raise ValueError("Plan42 input must be a JSON object with nodes[]")
    return path, spec


def tools_available() -> dict[str, str]:
    cmd = [sys.executable, str(TOOL), "--list-targets"]
    res = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=20, check=True)
    found = {}
    for line in res.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2:
            found[parts[0]] = parts[1]
    return found


def discover() -> dict[str, Any]:
    targets = tools_available()
    return {
        "schema": SCHEMA, "ok": True, "operation": "discover", "capability": "plan42.compile",
        "intention_ids": ["plan42.discover", "plan42.inspect", "plan42.compile", "plan42.native.plan", "plan42.native.inventory"],
        "estate_candidate": "estate/plan42.estate.candidate.json",
        "estate_registration": "candidate-unpublished",
        "targets": targets,
        "preferred_native_rexx_targets": sorted(NATIVE_TARGETS & targets.keys()),
        "native_rexx_available": shutil.which("rexx") is not None,
        "execute_generated": False, "publish": False, "dispatch": False,
        "semantics": "inspect/compile only, no generated execution, no class publication",
    }


def inspect(name: str) -> dict[str, Any]:
    path, spec = load_spec(name)
    counts: Counter[str] = Counter()
    preferred = set()
    findings = []
    def visit(obj: Any) -> None:
        if isinstance(obj, dict):
            op = obj.get("op")
            if isinstance(op, str):
                counts[op] += 1
                if op == "impl_use" and str(obj.get("name", "")).startswith("preferred."):
                    preferred.add(obj["name"])
            sf = obj.get("security_findings")
            if isinstance(sf, list):
                findings.extend(sf)
            for value in obj.values():
                visit(value)
        elif isinstance(obj, list):
            for v in obj:
                visit(v)
    visit(spec)
    return {
        "schema": SCHEMA, "ok": True, "operation": "inspect", "module": spec.get("module"),
        "spec": spec.get("spec"), "source": str(path.relative_to(ROOT)), "source_sha256": sha(path),
        "node_counts": dict(sorted(counts.items())), "preferred_references": sorted(preferred),
        "security_findings": findings, "executed": False,
    }


def compile_spec(name: str, target: str, output: str | None, engine: str, strict: bool) -> dict[str, Any]:
    source, spec = load_spec(name)
    targets = tools_available()
    if target not in targets:
        return failure("unsupported-target", "target is not registered", target=target)
    if targets[target] == "registered":
        return failure("unsupported-target", "target is registered only; no compiler", target=target, target_maturity=targets[target])
    if engine not in {"auto", "python", "native"}:
        return failure("invalid-engine", "engine must be auto, python, or native")
    if engine == "native" and target not in NATIVE_TARGETS:
        return failure("invalid-route", "native ooRexx generator does not own this target", target=target)
    use_native = engine == "native" or (engine == "auto" and target in NATIVE_TARGETS and shutil.which("rexx") is not None)
    if use_native and shutil.which("rexx") is None:
        return failure("runtime-unavailable", "native ooRexx route requested but rexx is unavailable", target=target, no_silent_fallback=True)
    if GENERATED.is_symlink() or not inside(ROOT, GENERATED):
        return failure("unsafe-output-root", "generated output root is outside Alchemy")
    GENERATED.mkdir(parents=True, exist_ok=True)
    stem = re.sub(r"[^A-Za-z0-9_.-]", "_", str(spec.get("module") or source.stem))[:70] or "spec"
    dest = path_within(GENERATED, output, must_exist=False) if output else GENERATED / (stem + EXTENSIONS.get(target, ".txt"))
    if dest.is_dir():
        return failure("invalid-output", "output path is a directory")
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Staging confines all compiler byproducts; a failed compiler cannot replace a prior artifact.
    with tempfile.TemporaryDirectory(prefix="stage-", dir=GENERATED) as dirname:
        stage = Path(dirname)
        emitted = stage / ("emitted" + EXTENSIONS.get(target, ".txt"))
        diag = stage / "diagnostics.json"
        compat = stage / "compatibility.json"
        compiler_cmd = [sys.executable, str(TOOL), str(source), "--target", target,
                        "-o", str(emitted), "--diagnostics", str(diag), "--compatibility", str(compat)]
        if strict:
            compiler_cmd.append("--fail-on-incompatible")
        try:
            preflight = subprocess.run(compiler_cmd, cwd=ROOT, capture_output=True, text=True, timeout=45, check=False)
        except subprocess.TimeoutExpired:
            return failure("timeout", "canonical compiler preflight timed out", target=target)
        evidence: dict[str, Any] = {}
        for path, key in ((diag, "diagnostics"), (compat, "compatibility")):
            if path.exists():
                try:
                    evidence[key] = json.loads(path.read_text(encoding="utf-8"))
                except (ValueError, OSError):
                    evidence[key] = {"status": "unreadable"}
        if preflight.returncode or not emitted.is_file():
            return failure("refused", "canonical compiler refused input or target", target=target,
                           compiler_rc=preflight.returncode, stderr=preflight.stderr[-2500:], **evidence)
        selected_engine = "oorexx-native" if use_native else "python-canonical"
        if use_native:
            emitted.unlink()  # native output must be fresh, not the canonical preflight artifact
            # Refuse if the REXX wrapper does not produce the requested output. No execution of generated code.
            cmd = ["rexx", str(ROOT / "run_plan42.rex"), str(source), "--target", target,
                   "--dry-run", "--output", str(stage / emitted.name), "--quiet"]
            try:
                run = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=45)
            except subprocess.TimeoutExpired:
                return failure("timeout", "native generator timed out", target=target)
            if run.returncode:
                return failure("native-refused", "native generator failed; no fallback used", target=target,
                               native_rc=run.returncode, stderr=run.stderr[-2500:], **evidence)
            if not emitted.exists() or not emitted.stat().st_size:
                return failure("native-invalid", "native generator produced no output", target=target)
            evidence["native_validation"] = "generated-only; no runtime equivalence asserted"
        os.replace(emitted, dest)
        out_digest = sha(dest)
    return {"schema": SCHEMA, "ok": True, "operation": "compile", "status": "generated",
            "target": target, "target_maturity": targets[target], "engine": selected_engine,
            "source": str(source.relative_to(ROOT)), "source_sha256": sha(source),
            "output": str(dest.relative_to(ROOT)), "output_sha256": out_digest,
            "executed": False, "published": False, "dispatched": False, "strict": strict, **evidence}


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=["discover", "inspect", "compile", "native-plan", "native-inventory"])
    p.add_argument("--spec")
    p.add_argument("--target")
    p.add_argument("--output")
    p.add_argument("--engine", choices=["auto", "python", "native"], default="auto")
    p.add_argument("--allow-degraded", action="store_true")
    p.add_argument("--source")
    p.add_argument("--mode", choices=["standalone", "native-package"])
    p.add_argument("--compiler-root")
    p.add_argument("--receipt")
    p.add_argument("--model")
    p.add_argument("--expected-sha256")
    ns = p.parse_args(argv)
    try:
        if ns.action == "discover":
            result = discover()
        elif ns.action == "inspect":
            if not ns.spec:
                raise ValueError("--spec required for inspect")
            result = inspect(ns.spec)
        elif ns.action == "native-inventory":
            if not ns.source or not ns.model or not ns.mode:
                raise ValueError("--source, --model and --mode required for native-inventory")
            result = native_inventory(ns.source, ns.model, ns.mode)
        elif ns.action == "native-plan":
            if not ns.source or not ns.mode:
                raise ValueError("--source and --mode required for native-plan")
            result = native_build_plan(ns.source, ns.mode, ns.compiler_root,
                                       ns.expected_sha256, ns.receipt, ns.model)
        else:
            if not ns.spec or not ns.target:
                raise ValueError("--spec and --target required for compile")
            result = compile_spec(ns.spec, ns.target, ns.output, ns.engine, strict=not ns.allow_degraded)
    except (OSError, ValueError, json.JSONDecodeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        result = failure("error", str(exc))
    print(json.dumps(result, sort_keys=True, ensure_ascii=True))
    return 0 if result.get("ok") else 1

if __name__ == "__main__":
    sys.exit(main())
