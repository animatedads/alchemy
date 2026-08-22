#!/usr/bin/env python3
"""Alchemy Autobuild v0.5: branch-tree Git inbox adapter.

Extends v0.4.2. Remote AI branches are transport envelopes: the runner fetches
refs and reads package objects directly. It never checks out, merges or rebases a
submission branch into main.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import tempfile
from pathlib import Path

from branch_inbox import BranchSubmission, pending_submissions, read_ready, materialize_package


def _load_v042():
    here = Path(__file__).resolve()
    candidates = []
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo:
        candidates.append(Path(repo) / "packages/alchemy_autobuild_v0.4.2/alchemy_autobuild.py")
    candidates.append(here.parents[1] / "alchemy_autobuild_v0.4.2/alchemy_autobuild.py")
    for path in candidates:
        if path.is_file():
            spec = importlib.util.spec_from_file_location("alchemy_autobuild_v042_base", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    raise RuntimeError("alchemy_autobuild_v0.4.2 dependency not found")


_base = _load_v042()
for _name in dir(_base):
    if not _name.startswith("__") and _name not in globals():
        globals()[_name] = getattr(_base, _name)

RESULT_SCHEMA = "alchemy.autobuild.result/0.5"
MSG_SCHEMA = "alchemy.mesh.autobuild/0.5"
_v3 = _base._v4._v3
_local_pending = _v3.git_pending_submissions
_local_integrate_git = _v3.integrate_git_submission


def git_pending_submissions(c):
    local = _local_pending(c)
    local_ids = {p.name for p in local}
    branches = pending_submissions(
        c["repo"], remote="origin", base=c["branch"],
        inbox=c["git_inbox"], receipts=c["git_receipts"],
    )
    return local + [b for b in branches if b.name not in local_ids]


def _reject_branch(c, sub, start_ns, error):
    sid = sub.name
    token = hashlib.sha256((sid + "\0" + sub.commit).encode()).hexdigest()[:12]
    rid = f"{_base.stamp()}-gitbranch-{token}"
    rd = Path("autobuild/results") / rid
    receipt_rel = Path(c["git_receipts"]) / (sid + ".json")
    mr = Path("mesh/ctl") / (c["ipc_from"] + "-" + c["ipc_to"]) / (_base.stamp() + "-gitbranch-" + token + ".msg")
    source_path = str(Path(c["git_inbox"]) / sid)
    source = dict(kind="git-branch", submission_id=sid, source_path=source_path,
                  source_branch=sub.branch_name, source_ref=sub.branch_ref, source_commit=sub.commit)
    res = dict(schema=RESULT_SCHEMA, run_id=rid, status="ERROR",
               runner=dict(started_ns=start_ns, started_at=_base.iso(start_ns)),
               source=source, error=str(error))
    _base.write_json(c["repo"] / rd / "result.json", res)
    _base.write_json(c["repo"] / receipt_rel, dict(
        schema=_base.GIT_RECEIPT_SCHEMA, submission_id=sid, status="ERROR",
        source_branch=sub.branch_name, source_commit=sub.commit,
        result_path=str(rd / "result.json"), error=str(error)))
    md = c["repo"] / mr
    md.parent.mkdir(parents=True, exist_ok=True)
    md.write_text("EVENT|" + json.dumps(dict(
        schema=MSG_SCHEMA, knd="AUTOBUILD_RESULT", src=c["ipc_from"], dst=c["ipc_to"],
        run_id=rid, status="ERROR", submission_id=sid, source_branch=sub.branch_name,
        result_path=str(rd / "result.json"), error=str(error)), sort_keys=True) + "\n")
    _base.commit_push(c, [str(rd), str(receipt_rel), str(mr)], "autobuild: reject branch submission " + sid)
    return res


def _integrate_branch(c, sub: BranchSubmission, start_ns):
    c["root"].mkdir(parents=True, exist_ok=True)
    (c["root"] / "staging").mkdir(exist_ok=True)
    try:
        ready = _base.validate_ready(read_ready(c["repo"], sub), sub.name)
        package_path = ready.get("package_path", "package")
        with tempfile.TemporaryDirectory(prefix="git-branch-", dir=c["root"] / "staging") as td:
            materialized = Path(td) / "package"
            source_path = materialize_package(c["repo"], sub, package_path, materialized)
            if not (materialized / "integration.json").is_file():
                raise ValueError("branch submission package/integration.json not found")
            snap = Path(td) / (_base.sname(sub.name) + ".zip")
            tree_hash = _base.deterministic_zip_tree(materialized, snap)
            manifest = _base.manifest(snap)
            if manifest is None:
                raise ValueError("branch submission integration.json not found at package root")
            receipt_rel = (Path(c["git_receipts"]) / (sub.name + ".json")).as_posix()
            source_meta = dict(
                kind="git-branch", submission_id=sub.name, source_path=source_path,
                source_branch=sub.branch_name, source_ref=sub.branch_ref,
                source_commit=sub.commit, tree_sha256=tree_hash,
                filename=None, mtime_ns=None, ctime_ns=None, arrival_ns=None,
            )
            receipt = dict(path=receipt_rel, data=dict(
                submission_id=sub.name, submitted_by=ready.get("submitted_by"),
                source_path=source_path, source_branch=sub.branch_name,
                source_ref=sub.branch_ref, source_commit=sub.commit, tree_sha256=tree_hash,
            ))
            run_tag = hashlib.sha256(sub.name.encode()).hexdigest()[:8]
            return _base.integrate(snap, snap.stat(), manifest, c, start_ns,
                                   source_meta=source_meta, sync=False,
                                   receipt=receipt, run_tag=run_tag)
    except Exception as e:
        return _reject_branch(c, sub, start_ns, e)


def integrate_git_submission(c, sub, start_ns):
    if isinstance(sub, BranchSubmission):
        return _integrate_branch(c, sub, start_ns)
    return _local_integrate_git(c, sub, start_ns)


_v3.git_pending_submissions = git_pending_submissions
_v3.integrate_git_submission = integrate_git_submission
_v3.RESULT_SCHEMA = RESULT_SCHEMA
_v3.MSG_SCHEMA = MSG_SCHEMA
_base.RESULT_SCHEMA = RESULT_SCHEMA
_base.MSG_SCHEMA = MSG_SCHEMA


def main():
    return _base.main()


if __name__ == "__main__":
    main()
