#!/usr/bin/env python3
"""Compare exact owned archive members with an Alchemy Git source tree.

Read-only, independent of Autobuilder. A result is SOURCE_PARITY, never
runtime qualification, accepted release or installed-service evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import sys
from zipfile import ZipFile, BadZipFile

SCHEMA = "alchemy.delivery-parity/0.1"
EXCLUDED_DIRS = {"dependencies", "deps", "vendor", "third_party", "third-party", "externals", "__pycache__", ".git"}
EXCLUDED_SUFFIXES = {".pyc", ".pyo"}
KNOWN_PACKAGE_ROOTS = {"src", "test", "tests", "docs", "fixtures", "examples", "contracts", "tools", "rexx", "native", "include", "bin", "lib", "bridge"}

class UnsafeArchive(ValueError):
    pass


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _safe_name(raw: str) -> PurePosixPath:
    if not raw or "\\" in raw or "\x00" in raw or "//" in raw:
        raise UnsafeArchive(f"Invalid archive member name: {raw!r}")
    path = PurePosixPath(raw)
    if path.is_absolute() or any(part in ("..", "") for part in path.parts) or raw.startswith("./"):
        raise UnsafeArchive(f"Unsafe archive member: {raw!r}")
    if path.parts[0].endswith(":"):
        raise UnsafeArchive(f"Drive-qualified archive member: {raw!r}")
    return path


def _excluded(parts: tuple[str, ...]) -> bool:
    return any(p.lower() in EXCLUDED_DIRS for p in parts[:-1]) or parts[-1].lower().endswith(tuple(EXCLUDED_SUFFIXES))


def _source_files(archive: Path, prefix: str = "auto") -> tuple[list[tuple[str, bytes]], list[str], str]:
    seen = set()
    with ZipFile(archive) as z:
        members = []
        for info in z.infolist():
            name = _safe_name(info.filename)
            if info.is_dir():
                continue
            mode = (info.external_attr >> 16) & 0xFFFF
            if stat.S_ISLNK(mode):
                raise UnsafeArchive(f"Archive symlink is not source: {info.filename}")
            if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
                raise UnsafeArchive(f"Non-regular archive entry: {info.filename}")
            if info.file_size > 64 * 1024 * 1024:
                raise UnsafeArchive(f"Oversized member: {info.filename}")
            members.append((name, info))
        parts = [name.parts for name, _ in members]
        if prefix == "auto":
            if parts and parts[0][0].lower() not in KNOWN_PACKAGE_ROOTS and all(len(p) > 1 and p[0] == parts[0][0] for p in parts):
                root = parts[0][0]
            else:
                root = ""
        elif prefix == "none":
            root = ""
        else:
            root = prefix.strip("/")
            if not root or "/" in root or root in (".", ".."):
                raise UnsafeArchive("--strip-prefix must be one top-level directory or 'none'/'auto'")
            if not all(p[0] == root and len(p) > 1 for p in parts):
                raise UnsafeArchive(f"Archive does not consistently use prefix {root!r}")
        included, omitted = [], []
        for name, info in members:
            rel = name.parts[1:] if root else name.parts
            key = "/".join(rel)
            if not key or key.casefold() in seen:
                raise UnsafeArchive(f"Duplicate or empty member path: {key!r}")
            seen.add(key.casefold())
            if _excluded(rel):
                omitted.append(key)
            else:
                included.append((key, z.read(info)))
    return sorted(included), sorted(omitted), root


def compare(archive: Path, destination: Path, strip_prefix: str = "auto") -> dict:
    archive = archive.resolve(strict=True)
    destination = destination.resolve(strict=True)
    if not destination.is_dir():
        raise ValueError("Destination must be a real directory")
    selected, excluded, root = _source_files(archive, strip_prefix)
    rows = []
    for member, data in selected:
        path = destination.joinpath(*PurePosixPath(member).parts)
        if path.is_symlink():
            status, actual = "UNSAFE_DESTINATION", None
        elif not path.is_file():
            status, actual = "MISSING", None
        else:
            # Resolve each file: reject symlinks in any parent, not only leaf.
            if not path.resolve().is_relative_to(destination):
                status, actual = "UNSAFE_DESTINATION", None
            else:
                actual = _sha(path.read_bytes())
                status = "MATCH" if actual == _sha(data) else "DIFFERENT"
        rows.append({"path": member, "status": status, "archive_sha256": _sha(data), "git_tree_sha256": actual})
    counts = {key: sum(r["status"] == key for r in rows) for key in ("MATCH", "MISSING", "DIFFERENT", "UNSAFE_DESTINATION")}
    return {
        "schema": SCHEMA,
        "archive_name": archive.name,
        "archive_sha256": _sha(archive.read_bytes()),
        "strip_prefix": root,
        "destination": str(destination),
        "verdict": "SOURCE_PARITY" if rows and counts["MATCH"] == len(rows) else "SOURCE_GAP",
        "qualification": "NOT_ASSESSED",
        "acceptance": "NOT_ASSESSED",
        "deployment": "NOT_ASSESSED",
        "counts": {**counts, "included": len(rows), "excluded_dependency_or_cache": len(excluded)},
        "excluded_paths": excluded,
        "members": rows,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path, help="immutable delivery ZIP")
    parser.add_argument("--destination", required=True, type=Path, help="exact corresponding Git package/sphere directory")
    parser.add_argument("--strip-prefix", default="auto", help="auto (default), none, or archive's one root directory")
    parser.add_argument("--json", action="store_true", help="machine-readable evidence (includes per-file hashes)")
    args = parser.parse_args(argv)
    try:
        result = compare(args.archive, args.destination, args.strip_prefix)
    except (ValueError, UnsafeArchive, BadZipFile, OSError) as exc:
        if args.json:
            print(json.dumps({"schema": SCHEMA, "verdict": "AUDIT_ERROR", "error": str(exc)}, sort_keys=True))
        else:
            print(f"AUDIT_ERROR: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"{result['verdict']}: {result['archive_name']} -> {result['destination']}")
        print(" ".join(f"{k}={v}" for k, v in result["counts"].items()))
        for row in result["members"]:
            if row["status"] != "MATCH":
                print(f"{row['status']}: {row['path']}")
        print("Runtime qualification, receiver acceptance and deployment: NOT_ASSESSED")
    return 0 if result["verdict"] == "SOURCE_PARITY" else 1


if __name__ == "__main__":
    raise SystemExit(main())
