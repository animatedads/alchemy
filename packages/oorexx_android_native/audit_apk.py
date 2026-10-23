#!/usr/bin/env python3
"""Static Android APK ELF closure audit. No mutation or install claims."""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path

SYSTEM = {
    "libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so",
    "libjnigraphics.so", "libz.so", "libEGL.so", "libGLESv2.so",
    "libOpenSLES.so", "libvulkan.so", "libmediandk.so", "libaaudio.so",
}
HOST = "libwire_mobile_host.so"
JNI = "Java_org_oorexx_wire_mobile_WireOoRexxRuntime_nativeStart"

def readelf(flag, path):
    p = subprocess.run(["readelf", flag, str(path)], text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stderr.strip() or "readelf failed")
    return p.stdout

def inspect(apk, require_host=False):
    apk = Path(apk)
    findings, needed, exports = [], {}, {}
    def error(kind, **kw):
        findings.append(dict(level="error", kind=kind, **kw))
    with zipfile.ZipFile(apk) as z:
        names = z.namelist()
        libs = {Path(n).name: n for n in names if n.startswith("lib/arm64-v8a/") and n.endswith(".so")}
        if not libs:
            error("missing_arm64_libraries")
        if require_host and HOST not in libs:
            error("missing_host")
        with tempfile.TemporaryDirectory() as temp:
            for name, member in libs.items():
                path = Path(temp) / name
                path.write_bytes(z.read(member))
                try:
                    header, dynamic, symbols = (readelf(f, path) for f in ("-h", "-d", "-Ws"))
                except (OSError, RuntimeError) as exc:
                    error("elf_read", library=name, detail=str(exc))
                    continue
                machine = re.search(r"Machine:\s*(.+)", header)
                if not machine or "AArch64" not in machine.group(1):
                    error("wrong_arch", library=name, machine=machine.group(1) if machine else None)
                deps = re.findall(r"\(NEEDED\).*?\[(.*?)\]", dynamic)
                needed[name] = deps
                for dep in deps:
                    if dep not in libs and dep not in SYSTEM:
                        error("unresolved_needed", library=name, needed=dep)
                exports[name] = JNI in symbols
                if "(RUNPATH)" in dynamic or "(RPATH)" in dynamic:
                    findings.append(dict(level="warning", kind="rpath_present", library=name))
        if HOST in libs:
            if not exports.get(HOST):
                error("missing_jni_export", expected=JNI)
            if not ({"assets/tiny.rex", "assets/mobile_main.rex"} & set(names)):
                error("missing_rexx_asset")
    return {
        "apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
        "arm64_libraries": sorted(libs), "needed": needed,
        "jni_export_present": exports, "findings": findings,
        "pass": not any(f["level"] == "error" for f in findings),
    }

def main():
    p = argparse.ArgumentParser()
    p.add_argument("apk", nargs="+")
    p.add_argument("--require-host", action="store_true")
    p.add_argument("--output")
    args = p.parse_args()
    report = {"schema": "android.native.closure.audit/1",
              "results": [inspect(x, args.require_host) for x in args.apk]}
    data = json.dumps(report, indent=2)
    if args.output:
        Path(args.output).write_text(data + "\n")
    print(data)
    return 0 if all(r["pass"] for r in report["results"]) else 2

if __name__ == "__main__":
    raise SystemExit(main())
