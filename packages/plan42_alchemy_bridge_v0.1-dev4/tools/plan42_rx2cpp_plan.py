#!/usr/bin/env python3
"""Non-executing Plan42 -> ooRexx -> RX2CPP native build-plan boundary.

It is intentionally NOT a generic C++ Plan42 compiler. It never invokes RX2CPP,
executes generated programs, publishes a native library, or registers a class.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
GENERATED = ROOT / "generated" / "plan42"
API = "plan42.rx2cpp.plan/0.1"
GITHUB = "animatedads/oorexx"
PIN = "9047f0e13c8cd67acf4258bd69cf78ea946944ac"  # observed main, 2026-10-15
VERSION = "0.30.18"
MODES = {"standalone": ".rex", "native-package": ".cls"}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def refuse(status: str, reason: str, **fields: object) -> dict:
    return {"schema": API, "ok": False, "status": status, "reason": reason,
            "executed": False, "published": False, "replaced": False, **fields}


def within(root: Path, candidate: Path) -> bool:
    return candidate.is_relative_to(root.resolve())


def source_file(name: str, mode: str) -> Path:
    if mode not in MODES:
        raise ValueError("mode must be standalone or native-package")
    src = Path(name)
    src = (src if src.is_absolute() else ROOT / src)
    generated = GENERATED.resolve()
    if GENERATED.is_symlink():
        raise ValueError("generated boundary is a symlink")
    # Resolve before reading and reject links even where final resolution stayed inside.
    if src.is_symlink() or not within(generated, src.resolve()):
        raise ValueError("source is not an unlinked generated/plan42 file")
    src = src.resolve()
    if not src.is_file():
        raise ValueError("generated source is missing")
    if src.suffix.lower() != MODES[mode]:
        raise ValueError(f"{mode} requires {MODES[mode]} source")
    return src


def git_head(path: Path) -> str | None:
    if not (path / ".git").exists():
        return None
    try:
        p = subprocess.run(["git", "-C", str(path), "rev-parse", "--verify", "HEAD"],
                           capture_output=True, text=True, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None
    head = p.stdout.strip()
    return head if p.returncode == 0 and re.fullmatch("[a-f0-9]{40}", head) else None


def check_receipt(pathname: str | None, src: Path, src_hash: str) -> dict:
    if not pathname:
        return {"status": "not-supplied", "verified": False}
    path = (ROOT / pathname).resolve() if not Path(pathname).is_absolute() else Path(pathname).resolve()
    if not within(ROOT, path) or path.is_symlink() or not path.is_file():
        raise ValueError("compiler receipt must be a workspace file")
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        raise ValueError("compiler receipt must be a JSON object")
    if obj.get("schema") != "plan42.integration/0.1" or obj.get("operation") != "compile":
        raise ValueError("not an Alchemy Plan42 compiler receipt")
    if not obj.get("ok") or obj.get("target") not in {"oorexx", "oo-rexx", "oo_rexx", "orx"}:
        raise ValueError("compiler receipt did not generate an ooRexx target")
    for flag in ("executed", "published", "dispatched"):
        if obj.get(flag) is True:
            raise ValueError("receipt asserts a prohibited side effect")
    declared = obj.get("output", "")
    actual = (ROOT / declared).resolve() if not Path(declared).is_absolute() else Path(declared).resolve()
    if actual != src or obj.get("output_sha256") != src_hash:
        raise ValueError("generated source does not match compiler receipt")
    comp = obj.get("compatibility")
    return {"status": "matched", "verified": True, "receipt_sha256": digest(path),
            "input_sha256": obj.get("source_sha256"), "engine": obj.get("engine"),
            "compatibility": comp, "plan42_native_compatibility":
            isinstance(comp, dict) and comp.get("status") == "native"}


def plan(source: str, mode: str, compiler_root: str | None = None,
         expected_sha256: str | None = None, receipt: str | None = None,
         model: str | None = None) -> dict:
    try:
        src = source_file(source, mode)
        current = digest(src)
        if expected_sha256 and current != expected_sha256:
            return refuse("source-changed", "expected generated ooRexx digest differs", source_sha256=current)
        receipt_result = check_receipt(receipt, src, current)
        # RX2CPP owns declaration discovery. Import its object-model stream
        # without inspecting ooRexx source with a competing parser.
        # This is an UNATTESTED scope proposal, not executable compiler input.
        inventory_result = None
        if model:
            from plan42_rx2cpp_inventory import load_inventory
            inventory_result = load_inventory(str(src), model, mode)
            if not inventory_result['ok']:
                return refuse('inventory-refused', inventory_result.get('reason', 'invalid inspector model'),
                              source_sha256=current)
        basename = "p42_" + re.sub(r"[^A-Za-z0-9_]", "_", src.stem)[:56]
        if not basename:
            return refuse("unsafe-name", "source basename is empty")
        destination = GENERATED / "native" / basename
        result = {
            "schema": API, "ok": True, "operation": "native-plan", "status": "PROPOSED_ONLY",
            "source": str(src.relative_to(ROOT)), "source_sha256": current,
            "mode": mode, "plan42_receipt": receipt_result,
            "native_output_directory": str(destination.relative_to(ROOT)),
            "rx2cpp_repository": GITHUB, "expected_revision": PIN, "expected_version": VERSION,
            "compiler_implementation_language": "ooRexx",
            "code_unit_authority": "RX2CPP interpreter-owned inspection and scope (not Plan42 heuristics)",
            "semantic_equivalence": "UNVERIFIED", "native_qualification": "NOT_RUN",
            "executed": False, "published": False, "replaced": False,
            "codelet_define_authorised": False, "registry_published": False,
            "requires": ["exact-source-and-receipt-review", "rx2cpp-checkout-pin",
                         "interpreter-native-differential-qualification", "governed-publication"],
        }
        if inventory_result is not None:
            result['inspector_inventory'] = {
                'status': 'IMPORTED_UNATTESTED',
                'model_sha256': inventory_result['model_sha256'],
                'source_sha256': inventory_result['source_sha256'],
                'export_authenticity_verified': False,
                'units': [{field: u[field] for field in ('kind', 'owner', 'selector', 'scope',
                                                        'visibility', 'flags', 'source_sha256')}
                          for u in inventory_result['units']],
            }
            result['requires'].append('pinned-interpreter-object-model-capture-and-verification')
        if compiler_root:
            repo = Path(compiler_root).resolve()
            rx = repo / "oorexx2cpp" if (repo / "oorexx2cpp").is_dir() else repo
            ver = rx / "VERSION"
            build = rx / ("native/build.sh" if mode == "native-package" else "build.sh")
            driver = rx / ("rx2cpp_native_library.rex" if mode == "native-package" else "rx2cpp.rex")
            if not ver.is_file() or ver.read_text(encoding="utf-8").strip() != VERSION:
                return refuse("compiler-version-mismatch", "RX2CPP VERSION is missing or unpinned", source_sha256=current)
            if not build.is_file():
                return refuse("compiler-interface-missing", "RX2CPP build entry point is missing", source_sha256=current)
            head = git_head(repo) or git_head(rx)
            result["checkout_revision"] = head
            result["checkout_pin_verified"] = head == PIN
            result["build_script_sha256"] = digest(build)
            result["version_file_sha256"] = digest(ver)
            result["driver_exists"] = driver.is_file()
            if not result["checkout_pin_verified"] or not result["driver_exists"]:
                result["status"] = "REVIEW_REQUIRED"
                result["requires"].append("verify-compiler-checkout-and-entrypoint")
            elif not receipt_result.get("plan42_native_compatibility"):
                result["status"] = "REVIEW_REQUIRED"
                result["requires"].append("obtain-native-compatible-Plan42-receipt")
            else:
                # A proposed argv is evidence for human/operator review, never executed here.
                if mode == "standalone":
                    argv = [str(build), str(src), str(destination / basename), str(destination / (basename + ".cpp"))]
                else:
                    argv = [str(build), str(src), str(destination), basename]
                result["proposed_build_argv"] = argv
                result["status"] = "READY_FOR_DIFFERENTIAL_QUALIFICATION"
        else:
            result["checkout_pin_verified"] = False
            result["requires"].append("supply-local-rx2cpp-checkout")
        if inventory_result is not None and result['status'] == 'READY_FOR_DIFFERENTIAL_QUALIFICATION':
            result['status'] = 'REVIEW_REQUIRED'
            result.pop('proposed_build_argv', None)
        return result
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return refuse("input-refused", str(exc))


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--source", required=True)
    p.add_argument("--mode", choices=MODES, required=True)
    p.add_argument("--compiler-root")
    p.add_argument("--expected-sha256")
    p.add_argument("--receipt")
    p.add_argument("--model")
    ns = p.parse_args(argv)
    response = plan(ns.source, ns.mode, ns.compiler_root, ns.expected_sha256, ns.receipt, ns.model)
    print(json.dumps(response, sort_keys=True))
    return 0 if response["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
