#!/usr/bin/env python3
"""Conservative structural audit for untrusted D-Bus source ZIPs."""
import argparse
import json
import pathlib
import stat
import zipfile

def audit(path, *, max_members=10000, max_total=1_000_000_000, max_ratio=1000):
    findings = []
    names = set()
    total = 0
    with zipfile.ZipFile(path) as archive:
        bad_member = archive.testzip()
        if bad_member:
            findings.append(f"CRC_FAILURE:{bad_member}")
        infos = archive.infolist()
        if len(infos) > max_members:
            findings.append("MEMBER_COUNT_LIMIT")
        for info in infos:
            raw = info.filename
            normal = raw.replace(chr(92), "/")
            parts = normal.split("/")
            canonical = "/".join(p for p in parts if p not in ("", ".")).casefold()
            if raw.startswith(("/", chr(92))) or (len(raw) > 1 and raw[1] == ":") or ".." in parts:
                findings.append(f"UNSAFE_PATH:{raw}")
            if canonical in names:
                findings.append(f"DUPLICATE_PATH:{raw}")
            names.add(canonical)
            if info.flag_bits & 1:
                findings.append(f"ENCRYPTED:{raw}")
            mode = info.external_attr >> 16
            if stat.S_IFMT(mode) == stat.S_IFLNK:
                findings.append(f"SYMLINK:{raw}")
            total += info.file_size
            if info.file_size and info.file_size / max(info.compress_size, 1) > max_ratio:
                findings.append(f"EXPANSION_RATIO:{raw}")
        if total > max_total:
            findings.append("TOTAL_SIZE_LIMIT")
    return {"archive": str(path), "members": len(infos), "uncompressed_bytes": total,
            "status": "PASS" if not findings else "FAIL", "findings": findings}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=pathlib.Path)
    args = parser.parse_args()
    try:
        result = audit(args.archive)
    except (OSError, zipfile.BadZipFile, RuntimeError, ValueError) as exc:
        result = {"archive": str(args.archive), "status": "FAIL", "findings": [type(exc).__name__]}
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["status"] == "PASS" else 1)

if __name__ == "__main__":
    main()
