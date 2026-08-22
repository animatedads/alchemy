#!/usr/bin/env python3
"""Seed one visible ooRexx dependency floor into packages/.

This is a bootstrap operation, NOT package acceptance. It is intentionally run
locally against a known consolidated bundle so Git receives the unpacked source
in one normal commit/push rather than thousands of provider-API writes.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

SEED_SCHEMA = "alchemy.bootstrap.dependency-seed/0.1"
SEMANTICS = "BOOTSTRAP_ONLY_NOT_ACCEPTANCE"
SIDE_PREFIX = "current/testapps/"


def run(argv, *, cwd=None, check=True):
    cp = subprocess.run(argv, cwd=cwd, text=True, stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE)
    if check and cp.returncode:
        msg = (cp.stderr or cp.stdout).strip()
        raise RuntimeError(f"command failed ({cp.returncode}): {' '.join(argv)}" +
                           (f"\n{msg}" if msg else ""))
    return cp


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_rel(name: str) -> Path:
    p = Path(name)
    if p.is_absolute() or ".." in p.parts:
        raise ValueError(f"unsafe archive path: {name}")
    return p


def normalized_name(archive_name: str, infos) -> tuple[str, str]:
    files = [i for i in infos if not i.is_dir()]
    tops = {i.filename.split("/")[0] for i in files if i.filename}
    if len(tops) == 1 and files and all("/" in i.filename for i in files):
        wrapper = next(iter(tops))
        return wrapper, wrapper + "/"
    base = Path(archive_name).name[:-4]
    base = re.sub(r"\(\d+\)$", "", base)
    return base, ""


def extract_nested(data: bytes, archive_name: str, dest: Path) -> str:
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        infos = z.infolist()
        pkgname, strip = normalized_name(archive_name, infos)
        target = dest / pkgname
        if target.exists():
            raise ValueError(f"duplicate package name in bundle: {pkgname}")
        target.mkdir(parents=True)
        for info in infos:
            if info.is_dir():
                continue
            rel = info.filename[len(strip):] if strip and info.filename.startswith(strip) else info.filename
            if not rel:
                continue
            out = target / safe_rel(rel)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(z.read(info))
            mode = (info.external_attr >> 16) & 0o777
            if mode:
                out.chmod(mode)
        return pkgname


def tree_hash(root: Path) -> str:
    h = hashlib.sha256()
    for p in sorted(root.rglob("*"), key=lambda x: x.relative_to(root).as_posix()):
        rel = p.relative_to(root).as_posix().encode()
        if p.is_symlink():
            raise ValueError(f"symlink not allowed in seed tree: {p}")
        if p.is_dir():
            h.update(b"D\0" + rel + b"\0")
        elif p.is_file():
            h.update(b"F\0" + rel + b"\0" + hashlib.sha256(p.read_bytes()).digest())
    return h.hexdigest()


def find_repo(explicit: str | None) -> Path:
    if explicit:
        repo = Path(explicit).expanduser().resolve()
    else:
        here = Path.cwd().resolve()
        repo = here
        while repo != repo.parent and not (repo / ".git").exists():
            repo = repo.parent
    if not (repo / ".git").exists():
        raise SystemExit("repository not found; use --repo")
    return repo


def find_bundle(explicit: str | None) -> Path:
    if explicit:
        p = Path(explicit).expanduser().resolve()
        if not p.is_file():
            raise SystemExit(f"bundle not found: {p}")
        return p
    downloads = Path.home() / "Downloads"
    matches = [p for p in downloads.iterdir()
               if p.is_file() and p.suffix.lower() == ".zip"
               and "oorexx-libs" in p.name
               and "crypto-consolidated" in p.name]
    if not matches:
        raise SystemExit("no crypto-consolidated oorexx-libs ZIP found in ~/Downloads; use --bundle")
    return max(matches, key=lambda p: (p.stat().st_ctime_ns, p.name))


def sync_main(repo: Path):
    remote_ref = "refs/remotes/origin/main"
    refspec = "+refs/heads/main:" + remote_ref
    run(["git", "-C", str(repo), "fetch", "origin", refspec])
    run(["git", "-C", str(repo), "checkout", "main"])
    dirty = run(["git", "-C", str(repo), "status", "--porcelain"]).stdout.strip()
    if dirty:
        raise RuntimeError("working tree is not clean; refusing bootstrap seed")
    run(["git", "-C", str(repo), "merge", "--ff-only", remote_ref])


def push_main(repo: Path):
    for attempt in range(3):
        cp = run(["git", "-C", str(repo), "push", "origin", "HEAD:refs/heads/main"], check=False)
        if cp.returncode == 0:
            return
        remote_ref = "refs/remotes/origin/main"
        refspec = "+refs/heads/main:" + remote_ref
        run(["git", "-C", str(repo), "fetch", "origin", refspec])
        run(["git", "-C", str(repo), "rebase", remote_ref])
    raise RuntimeError("unable to push dependency seed after 3 attempts")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo")
    ap.add_argument("--bundle")
    ap.add_argument("--dry-run", action="store_true")
    ns = ap.parse_args()

    repo = find_repo(ns.repo)
    bundle = find_bundle(ns.bundle)
    packages = repo / "packages"
    packages.mkdir(exist_ok=True)

    bundle_bytes = bundle.read_bytes()
    bundle_sha = sha256_bytes(bundle_bytes)
    seed_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-crypto-consolidated"
    ledger = {
        "schema": SEED_SCHEMA,
        "seed_id": seed_id,
        "source_bundle": bundle.name,
        "source_bundle_sha256": bundle_sha,
        "status_semantics": SEMANTICS,
        "entries": [],
    }

    with tempfile.TemporaryDirectory(prefix="alchemy-dependency-seed-") as td:
        stage = Path(td) / "packages"
        stage.mkdir()
        sidecars = []
        with zipfile.ZipFile(io.BytesIO(bundle_bytes)) as outer:
            for info in outer.infolist():
                if info.is_dir():
                    continue
                name = info.filename
                data = outer.read(info)
                if name.lower().endswith(".zip"):
                    pkgname = extract_nested(data, name, stage)
                    ledger["entries"].append({
                        "source": name,
                        "source_sha256": sha256_bytes(data),
                        "package_path": f"packages/{pkgname}",
                        "status": "PENDING",
                    })
                elif name.startswith(SIDE_PREFIX):
                    sidecars.append((name, data))

        if sidecars:
            side_name = "ourladyair_shannon_ticket_groups_v1"
            side_dir = stage / side_name
            side_dir.mkdir(exist_ok=True)
            for name, data in sidecars:
                (side_dir / Path(name).name).write_bytes(data)
                ledger["entries"].append({
                    "source": name,
                    "source_sha256": sha256_bytes(data),
                    "package_path": f"packages/{side_name}",
                    "status": "PENDING",
                })

        staged_names = sorted(p.name for p in stage.iterdir() if p.is_dir())
        if ns.dry_run:
            print(f"BUNDLE={bundle}")
            print(f"BUNDLE_SHA256={bundle_sha}")
            print(f"PACKAGE_TREES={len(staged_names)}")
            for name in staged_names:
                state = "PRESERVE" if (packages / name).exists() else "SEED"
                print(f"{state} packages/{name}")
            return

        sync_main(repo)
        new_paths = []
        for src in sorted(stage.iterdir(), key=lambda p: p.name):
            if not src.is_dir():
                continue
            dst = packages / src.name
            related = [e for e in ledger["entries"] if e["package_path"] == f"packages/{src.name}"]
            if dst.exists():
                existing_hash = tree_hash(dst)
                staged_hash = tree_hash(src)
                for e in related:
                    e["status"] = "EXISTING_PRESERVED"
                    e["existing_tree_sha256"] = existing_hash
                    e["seed_tree_sha256"] = staged_hash
                    e["identical"] = existing_hash == staged_hash
                continue
            shutil.copytree(src, dst)
            new_paths.append(dst)
            seeded_hash = tree_hash(dst)
            for e in related:
                e["status"] = "SEEDED"
                e["seed_tree_sha256"] = seeded_hash

    bootstrap = repo / "bootstrap"
    bootstrap.mkdir(exist_ok=True)
    ledger_path = bootstrap / f"dependency-seed-{seed_id}.json"
    ledger_path.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    paths = [str(ledger_path.relative_to(repo))] + [str(p.relative_to(repo)) for p in new_paths]
    run(["git", "-C", str(repo), "add", "--", *paths])
    status = run(["git", "-C", str(repo), "status", "--porcelain"]).stdout.strip()
    if status:
        run(["git", "-C", str(repo), "config", "user.name", "Alchemy Dependency Seeder"])
        run(["git", "-C", str(repo), "config", "user.email", "alchemy-dependency-seed@localhost"])
        run(["git", "-C", str(repo), "commit", "-m", f"bootstrap: seed ooRexx dependency floor {seed_id}"])
        push_main(repo)

    seeded = sorted({e["package_path"] for e in ledger["entries"] if e["status"] == "SEEDED"})
    preserved = sorted({e["package_path"] for e in ledger["entries"] if e["status"] == "EXISTING_PRESERVED"})
    print(f"SEED_ID={seed_id}")
    print(f"BUNDLE_SHA256={bundle_sha}")
    print(f"SEEDED={len(seeded)}")
    for p in seeded:
        print("  + " + p)
    print(f"EXISTING_PRESERVED={len(preserved)}")
    for p in preserved:
        print("  = " + p)
    print("PASS DEPENDENCY_FLOOR_SEEDED")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        raise
