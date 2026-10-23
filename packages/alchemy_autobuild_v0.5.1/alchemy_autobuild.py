#!/usr/bin/env python3
"""Alchemy Autobuild v0.5.1: service start repair and complete download intake.

Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.

Extends v0.5 without modifying it. v0.5 behaviour (branch-tree Git inbox) is
loaded and kept exactly. v0.5.1 changes three things only:

1. Start repair. v0.5 could not start as a service: it loads v0.4.2 by file
   path, and v0.4.2 executes `from git_sync import sync_repo`, but git_sync.py
   lives in the v0.4.2 directory, which is not on sys.path when v0.5 is the
   script being run. The service died with ModuleNotFoundError on every start
   since 22 Aug 2026. v0.5.1 puts the v0.5 and v0.4.2 directories on sys.path
   before loading, which is exactly the import environment the accepted v0.4.2
   service had.

2. Download intake. v0.3-v0.5 considered only the newest post-start ZIP, so a
   batch of downloads silently lost every ZIP but the last. v0.5.1 processes
   every post-start ZIP, oldest first, each exactly once, after it has been
   stable for two polls. A ZIP whose entries all sit under one top-level
   directory that contains integration.json is re-rooted into a deterministic
   snapshot and integrated; the original filename, SHA-256 and wrapper
   directory are recorded in the result. A ZIP with no integration.json is
   never integrated; the decision is written to the intake log.

3. Visibility and control. Every intake decision is appended to
   <root>/intake.log as one JSON line; `--status` prints the runner state and
   recent intake; `--list-pending` lists Git submissions that would run, without
   running them; config key "git_intake": false pauses the Git inbox (default
   true) so the service can be proven on a single download first.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
import tempfile
import time
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _packages_dir():
    # Under the autobuilder a package is tested from a temporary extraction, so
    # the sibling versions are found through ALCHEMY_REPO_ROOT (exported to every
    # test run). As a service it runs from <repo>/packages and uses its parent.
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo and (Path(repo) / "packages/alchemy_autobuild_v0.5/alchemy_autobuild.py").is_file():
        return Path(repo) / "packages"
    return HERE.parent


PACKAGES = _packages_dir()
V05_DIR = PACKAGES / "alchemy_autobuild_v0.5"
V042_DIR = PACKAGES / "alchemy_autobuild_v0.4.2"
INTAKE_SCHEMA = "alchemy.autobuild.intake/0.5.1"


def _load_v05():
    path = V05_DIR / "alchemy_autobuild.py"
    if not path.is_file():
        raise RuntimeError("alchemy_autobuild_v0.5 dependency not found: " + str(path))
    if not (V042_DIR / "git_sync.py").is_file():
        raise RuntimeError("alchemy_autobuild_v0.4.2/git_sync.py dependency not found")
    # The import environment the accepted v0.4.2 service ran with, plus v0.5's
    # own directory for branch_inbox.
    for d in (V042_DIR, V05_DIR):
        if str(d) not in sys.path:
            sys.path.insert(0, str(d))
    spec = importlib.util.spec_from_file_location("alchemy_autobuild_v05_base", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_v05 = _load_v05()
_base = _v05._base            # v0.4.2 module
_v3 = _base._v4._v3           # v0.3 engine; every layer patches its globals


def _intake_log(c, z, st, decision, **kw):
    rec = dict(schema=INTAKE_SCHEMA, at=_v3.iso(time.time_ns()), filename=Path(z).name,
               size=st.st_size, ctime_ns=st.st_ctime_ns, decision=decision)
    rec.update(kw)
    p = Path(c["root"]) / "intake.log"
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, sort_keys=True) + "\n")


def classify(z):
    """Return ("root", None), ("wrapped", topdir) or ("none", None)."""
    with zipfile.ZipFile(z) as f:
        names = [n for n in f.namelist() if n and not n.startswith("__MACOSX/")]
    if "integration.json" in names:
        return "root", None
    tops = {n.split("/", 1)[0] for n in names}
    if len(tops) == 1:
        top = next(iter(tops))
        if all(n.startswith(top + "/") for n in names) and (top + "/integration.json") in names:
            return "wrapped", top
    return "none", None


def candidates(downloads, start_ns):
    out = []
    try:
        entries = list(Path(downloads).iterdir())
    except FileNotFoundError:
        return out
    for p in entries:
        if not p.is_file() or p.suffix.lower() != ".zip":
            continue
        st = p.stat()
        if st.st_ctime_ns < start_ns:
            continue
        out.append((st.st_ctime_ns, p.name, p, st))
    out.sort(key=lambda x: (x[0], x[1]))
    return [(p, st) for _, _, p, st in out]


def process_zip(c, z, st, start_ns):
    """Integrate one stable ZIP. Returns the decision string."""
    try:
        kind, top = classify(z)
    except (zipfile.BadZipFile, EOFError):
        return "waiting-for-stable-zip"
    if kind == "none":
        _intake_log(c, z, st, "ignored-no-manifest")
        _v3.state(c, start_ns, "ignored-no-manifest", candidate=z.name)
        return "ignored-no-manifest"
    try:
        if kind == "root":
            m = _v3.manifest(z)
            _v3.state(c, start_ns, "running", candidate=z.name, package=m["package"])
            r = _v3.integrate(z, st, m, c, start_ns)
        else:
            staging = Path(c["root"]) / "staging"
            staging.mkdir(parents=True, exist_ok=True)
            with tempfile.TemporaryDirectory(prefix="wrapped-", dir=staging) as td:
                unpacked = Path(td) / "unpacked"
                unpacked.mkdir()
                _v3.extract(z, unpacked)
                snap = Path(td) / (_v3.sname(Path(z).stem) + ".zip")
                tree_hash = _v3.deterministic_zip_tree(unpacked / top, snap)
                m = _v3.manifest(snap)
                if m is None:
                    raise ValueError("wrapped ZIP lost integration.json during re-rooting")
                meta = dict(kind="zip-wrapped", filename=Path(z).name, wrapper_dir=top,
                            original_sha256=_v3.sha256(z), tree_sha256=tree_hash,
                            mtime_ns=st.st_mtime_ns, ctime_ns=st.st_ctime_ns,
                            arrival_ns=st.st_ctime_ns, size=st.st_size)
                _v3.state(c, start_ns, "running", candidate=z.name, package=m["package"], wrapper_dir=top)
                r = _v3.integrate(snap, snap.stat(), m, c, start_ns, source_meta=meta)
    except Exception as e:
        _intake_log(c, z, st, "integration-error", layout=kind, error=str(e))
        _v3.state(c, start_ns, "integration-error", candidate=z.name, error=str(e))
        return "integration-error"
    _intake_log(c, z, st, r["status"], layout=kind, run_id=r["run_id"],
                package=r.get("package"), published_tree=r.get("published_tree"))
    _v3.state(c, start_ns, r["status"].lower(), candidate=z.name, run_id=r["run_id"], outcome=r["status"])
    return r["status"]


class Runner:
    """One poll at a time, so tests can drive it deterministically."""

    def __init__(self, c, start_ns=None):
        self.c = c
        self.start_ns = time.time_ns() if start_ns is None else start_ns
        self.seen = {}
        self.handled = set()
        self.next_git_poll = 0.0
        Path(c["root"]).mkdir(parents=True, exist_ok=True)
        (Path(c["root"]) / "staging").mkdir(exist_ok=True)
        _v3.state(c, self.start_ns, "started", intake="all-post-start-zips-oldest-first/0.5.1")

    def poll_downloads(self):
        decisions = []
        for z, st in candidates(self.c["downloads"], self.start_ns):
            fp = (str(z), st.st_mtime_ns, st.st_ctime_ns, st.st_size)
            if fp in self.handled:
                continue
            if self.seen.get(str(z)) != fp:
                self.seen[str(z)] = fp
                _v3.state(self.c, self.start_ns, "observed", candidate=z.name, arrival_ns=st.st_ctime_ns)
                continue
            decision = process_zip(self.c, z, st, self.start_ns)
            if decision == "waiting-for-stable-zip":
                self.seen.pop(str(z), None)
                _v3.state(self.c, self.start_ns, decision, candidate=z.name)
                continue
            self.handled.add(fp)
            self.seen.pop(str(z), None)
            decisions.append((z.name, decision))
        return decisions

    def poll_git(self, force=False):
        if not self.c.get("git_intake", True):
            return []
        now = time.monotonic()
        if not force and now < self.next_git_poll:
            return []
        self.next_git_poll = now + self.c["git_poll"]
        out = []
        try:
            _v3.sync_repo(self.c)
            for sub in _v3.git_pending_submissions(self.c):
                _v3.state(self.c, self.start_ns, "git-running", submission_id=sub.name)
                r = _v3.integrate_git_submission(self.c, sub, self.start_ns)
                _v3.state(self.c, self.start_ns, "git-" + r["status"].lower(),
                          submission_id=sub.name, run_id=r["run_id"], outcome=r["status"])
                out.append((sub.name, r["status"]))
        except Exception as e:
            _v3.state(self.c, self.start_ns, "git-sync-error", error=str(e))
            out.append(("git-sync", "ERROR: " + str(e)))
        return out


def loop(c, once=False, start_ns=None):
    runner = Runner(c, start_ns)
    while True:
        runner.poll_downloads()
        runner.poll_git()
        if once:
            return runner
        time.sleep(c["poll"])


def status(c, lines=15):
    root = Path(c["root"])
    st = root / "runner-state.json"
    print("runner-state:", st)
    print(st.read_text() if st.is_file() else "  (missing: service has never started with this root)")
    log = root / "intake.log"
    print("intake.log (last %d):" % lines, log)
    if log.is_file():
        for line in log.read_text().splitlines()[-lines:]:
            print("  " + line)
    else:
        print("  (empty)")


def load_config(path=None):
    c = _v3.config(path)
    c["git_intake"] = True
    if path:
        raw = json.loads(Path(path).read_text())
        if "git_intake" in raw:
            c["git_intake"] = bool(raw["git_intake"])
    return c


def list_pending(c):
    """Fetch and list pending Git submissions. Runs nothing."""
    _v3.sync_repo(c)
    return [sub.name for sub in _v3.git_pending_submissions(c)]


# Anything that still enters through the v0.3 entry point gets the v0.5.1 loop.
_v3.loop = loop


def main(argv=None):
    a = argparse.ArgumentParser(description="Alchemy Autobuild v0.5.1")
    a.add_argument("--config")
    a.add_argument("--once", action="store_true")
    a.add_argument("--print-config", action="store_true")
    a.add_argument("--status", action="store_true")
    a.add_argument("--list-pending", action="store_true")
    n = a.parse_args(argv)
    c = load_config(n.config)
    if n.print_config:
        print(json.dumps({k: str(v) if isinstance(v, Path) else v for k, v in c.items()}, indent=2))
        return 0
    if n.status:
        status(c)
        return 0
    if n.list_pending:
        for name in list_pending(c):
            print(name)
        return 0
    loop(c, n.once)
    return 0


if __name__ == "__main__":
    sys.exit(main())
