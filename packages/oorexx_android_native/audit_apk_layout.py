#!/usr/bin/env python3
"""Fail-closed APK ZIP layout checks before Android installation.

This validates archive structure only; it does not certify APK signatures,
Android manifest compatibility, ABI loading, JNI calls, or handset execution.
"""
from __future__ import annotations
import argparse
import sys
import zipfile
from pathlib import PurePosixPath


def audit(path: str) -> list[str]:
    errors: list[str] = []
    try:
        with zipfile.ZipFile(path) as apk:
            names = apk.namelist()
            if len(names) != len(set(names)):
                errors.append("duplicate ZIP member names")
            for name in names:
                parts = name.split("/")
                if name.startswith("/") or "\\" in name or any(
                    part in ("", ".", "..") for part in parts[:-1]
                ) or (parts and parts[-1] in (".", "..")):
                    errors.append(f"unsafe or noncanonical member: {name!r}")
                if name.startswith("lib/") and name.endswith(".so"):
                    if len(parts) != 3 or not parts[1] or not parts[2]:
                        errors.append(f"invalid native library path: {name!r}")
            if "AndroidManifest.xml" not in names:
                errors.append("missing root AndroidManifest.xml")
            if "classes.dex" not in names:
                errors.append("missing root classes.dex (nested dex does not count)")
            if not any(n.startswith("lib/arm64-v8a/") and n.endswith(".so") for n in names):
                errors.append("missing arm64-v8a native libraries")
            if apk.testzip() is not None:
                errors.append("ZIP member CRC failure")
    except (OSError, zipfile.BadZipFile, RuntimeError) as exc:
        errors.append(f"unreadable APK: {exc}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", nargs="+")
    args = parser.parse_args()
    failed = False
    for path in args.apk:
        errors = audit(path)
        if errors:
            failed = True
            for error in errors:
                print(f"FAIL {path}: {error}", file=sys.stderr)
        else:
            print(f"PASS {path}: canonical APK ZIP layout")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
