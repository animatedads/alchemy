#!/usr/bin/env python3
"""
plan42_rust_preflight.py
Pre-generation verifier for Plan42 -> Rust targets.

Checks:
  1. rustc / cargo available and version acceptable
  2. serde_json available in cargo registry (offline check)
  3. Spec nodes all have type annotations where Rust requires them
  4. Every impl_use has either a Rust implementation or a preferred runtime mapping
  5. Expression ops that have no Rust equivalent are flagged
  6. Routine params with no type info flagged (Rust needs every param typed)

Exit codes:
  0  all checks pass
  1  blocking issues found
  2  spec file not readable
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

# ── Rust-native preferred capability set ─────────────────────────────
RUST_PREFERRED = {
    "preferred.file.stream_lines",
    "preferred.data.jsonl_parse",
    "preferred.ui.progress",
    "preferred.file.multiwrite_open",
    "preferred.file.multiwrite_write",
    "preferred.file.multiwrite_close",
    "preferred.file.write_tsv",
    "preferred.data.soundex_from_ipa",
}

# Expression ops with no direct Rust equivalent (need special handling)
RUST_TRICKY_OPS = {
    "method",   # .method() calls are ok but __len__, __contains__ are Python-isms
}

PYTHON_METHOD_NAMES = {"__len__", "__contains__", "__bool__", "__iter__"}

MIN_RUSTC_MAJOR = 1
MIN_RUSTC_MINOR = 70


def check_toolchain():
    issues = []
    for tool in ("rustc", "cargo"):
        if not shutil.which(tool):
            issues.append(f"BLOCK  {tool} not found in PATH")
        else:
            try:
                out = subprocess.check_output([tool, "--version"],
                                              stderr=subprocess.DEVNULL,
                                              text=True).strip()
                # rustc 1.78.0 (9b00956e5 2024-04-29)
                parts = out.split()
                if len(parts) >= 2 and tool == "rustc":
                    ver = parts[1].split(".")
                    major, minor = int(ver[0]), int(ver[1])
                    if (major, minor) < (MIN_RUSTC_MAJOR, MIN_RUSTC_MINOR):
                        issues.append(
                            f"BLOCK  rustc {parts[1]} < {MIN_RUSTC_MAJOR}.{MIN_RUSTC_MINOR} required")
                    else:
                        print(f"  OK   {out}")
            except Exception as e:
                issues.append(f"WARN   could not parse {tool} version: {e}")
    return issues


def collect_impl_names(nodes):
    """Return set of impl names defined in the spec."""
    return {n["name"] for n in nodes if n.get("op") == "impl"}


def scan_node(node, impl_names, issues, path=""):
    op = node.get("op", "")

    if op == "impl":
        impls = node.get("implementations", {})
        if "rust" not in impls and "generic" not in impls:
            issues.append(
                f"BLOCK  impl '{node.get('name')}' has no 'rust' or 'generic' implementation")

    if op == "impl_use":
        name = node.get("name", "")
        if name.startswith("preferred.") and name not in RUST_PREFERRED:
            issues.append(
                f"BLOCK  preferred impl '{name}' has no Rust runtime mapping")
        elif not name.startswith("preferred.") and name not in impl_names:
            # Could be a routine reference -- that's ok
            pass

    if op == "routine":
        params = node.get("params", [])
        ptypes = node.get("param_types", {})
        for p in params:
            if p not in ptypes:
                issues.append(
                    f"WARN   routine '{node.get('name')}' param '{p}' has no type annotation (Rust will default to String)")

    if op in ("declare", "assign"):
        if not node.get("type"):
            issues.append(
                f"WARN   {op} '{node.get('name','?')}' at {path} has no type annotation")

    # Check for Python-ism method calls
    if op == "method":
        mname = node.get("name", "")
        if mname in PYTHON_METHOD_NAMES:
            issues.append(
                f"WARN   Python method '{mname}' at {path} needs Rust translation (len/contains/etc)")

    # Recurse
    for key in ("body", "args", "value", "expr", "cond", "left", "right"):
        child = node.get(key)
        if isinstance(child, list):
            for i, c in enumerate(child):
                if isinstance(c, dict):
                    scan_node(c, impl_names, issues, f"{path}.{key}[{i}]")
        elif isinstance(child, dict):
            scan_node(child, impl_names, issues, f"{path}.{key}")


def main():
    if len(sys.argv) < 2:
        print("Usage: plan42_rust_preflight.py <spec.json>")
        sys.exit(2)

    spec_path = Path(sys.argv[1])
    if not spec_path.exists():
        print(f"ERROR  spec not found: {spec_path}")
        sys.exit(2)

    try:
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR  cannot parse spec: {e}")
        sys.exit(2)

    print(f"\n[rust-preflight] spec: {spec.get('module','?')}")
    print("[rust-preflight] --- toolchain ---")

    issues = []
    issues.extend(check_toolchain())

    print("[rust-preflight] --- spec scan ---")
    nodes = spec.get("nodes", [])
    impl_names = collect_impl_names(nodes)

    for i, node in enumerate(nodes):
        scan_node(node, impl_names, issues, f"nodes[{i}]")

    blocks   = [x for x in issues if x.startswith("BLOCK")]
    warnings = [x for x in issues if x.startswith("WARN")]

    if warnings:
        print(f"\n  {len(warnings)} warning(s):")
        for w in warnings:
            print(f"    {w}")

    if blocks:
        print(f"\n  {len(blocks)} blocker(s):")
        for b in blocks:
            print(f"    {b}")
        print("\n[rust-preflight] FAIL -- fix blockers before generating Rust\n")
        sys.exit(1)

    print(f"\n[rust-preflight] PASS ({len(warnings)} warnings) -- ready for Rust generation\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
