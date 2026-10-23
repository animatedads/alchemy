#!/usr/bin/env python3
"""Read-only source ZIP audit: inspect metadata BEFORE any decompression.

This checks archive structure/CRC within declared limits. It is NOT a malware
scanner, a code-review result, or proof that extracted files are safe to run.
"""
import argparse
import json
import pathlib
import stat
import unicodedata
import zipfile


def audit(path, *, max_members=10000, max_total=1_000_000_000,
          max_member=256 * 1024 * 1024, max_ratio=1000):
    findings = []
    names = set()
    declared_total = 0
    checked_total = 0
    members = 0
    integrity = "NOT_RUN"
    try:
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist()
            members = len(infos)
            if members > max_members:
                findings.append("MEMBER_COUNT_LIMIT")
            for info in infos:
                raw = info.filename
                norm = unicodedata.normalize("NFC", raw.replace("\\", "/"))
                parts = norm.split("/")
                key = "/".join(p for p in parts if p not in ("", ".")).casefold()
                if (not raw or norm.startswith("/") or raw.startswith("\\")
                    or (len(raw) > 1 and raw[1] == ":") or ".." in parts
                    or "\x00" in raw or "//" in norm or not key):
                    findings.append(f"UNSAFE_PATH:{raw}")
                if key in names:
                    findings.append(f"DUPLICATE_PATH:{raw}")
                names.add(key)
                if info.flag_bits & 1:
                    findings.append(f"ENCRYPTED:{raw}")
                mode = info.external_attr >> 16
                if stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                    findings.append(f"SPECIAL_FILE:{raw}")
                if info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                    findings.append(f"UNSUPPORTED_COMPRESSION:{raw}")
                declared_total += info.file_size
                if info.file_size > max_member:
                    findings.append(f"MEMBER_SIZE_LIMIT:{raw}")
                if info.file_size and info.file_size / max(info.compress_size, 1) > max_ratio:
                    findings.append(f"EXPANSION_RATIO:{raw}")
            if declared_total > max_total:
                findings.append("TOTAL_SIZE_LIMIT")
            # Failing metadata must NEVER lead to ZipFile.testzip/open.
            if not findings:
                integrity = "IN_PROGRESS"
                for info in infos:
                    current = 0
                    with archive.open(info, "r") as stream:
                        while chunk := stream.read(65536):
                            current += len(chunk)
                            checked_total += len(chunk)
                            if current > max_member or checked_total > max_total:
                                findings.append(f"DECOMPRESSED_SIZE_LIMIT:{info.filename}")
                                break
                    if findings:
                        break
                    if current != info.file_size:
                        findings.append(f"SIZE_MISMATCH:{info.filename}")
                        break
                integrity = "PASS" if not findings else "FAIL"
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile,
            RuntimeError, ValueError, EOFError, NotImplementedError) as exc:
        findings.append(f"INTEGRITY_ERROR:{type(exc).__name__}")
        integrity = "FAIL"
    return {"archive": str(path), "members": members,
            "declared_uncompressed_bytes": declared_total,
            "checked_uncompressed_bytes": checked_total,
            "integrity": integrity,
            "status": "PASS" if not findings and integrity == "PASS" else "FAIL",
            "findings": findings}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=pathlib.Path)
    args = parser.parse_args()
    result = audit(args.archive)
    print(json.dumps(result, indent=2, sort_keys=True))
    raise SystemExit(0 if result["status"] == "PASS" else 1)


if __name__ == "__main__":
    main()
