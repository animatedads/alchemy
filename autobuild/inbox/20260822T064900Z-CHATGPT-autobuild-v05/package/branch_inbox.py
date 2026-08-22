"""Read Alchemy Autobuild submissions from immutable remote Git branch trees."""
from __future__ import annotations

import io
import json
import os
import subprocess
import tarfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath


class BranchInboxError(RuntimeError):
    pass


@dataclass(frozen=True)
class BranchSubmission:
    name: str
    branch_name: str
    branch_ref: str
    commit: str
    ready_path: str


def _git(repo: Path, *args: str, binary: bool = False):
    try:
        cp = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=not binary,
        )
    except subprocess.CalledProcessError as e:
        err = e.stderr.decode(errors="replace") if binary and isinstance(e.stderr, bytes) else (e.stderr or "")
        raise BranchInboxError(f"git {' '.join(args)} failed: {err.strip()}") from e
    return cp.stdout


def fetch_remote_heads(repo: Path, remote: str = "origin") -> None:
    _git(repo, "fetch", remote, f"+refs/heads/*:refs/remotes/{remote}/*")


def pending_submissions(repo: Path, *, remote: str = "origin", base: str = "main",
                        inbox: str = "autobuild/inbox", receipts: str = "autobuild/receipts") -> list[BranchSubmission]:
    repo = Path(repo)
    fetch_remote_heads(repo, remote)
    base_ref = f"refs/remotes/{remote}/{base}"
    refs = _git(repo, "for-each-ref", "--format=%(refname)%09%(objectname)", f"refs/remotes/{remote}/")
    found: dict[str, BranchSubmission] = {}
    for line in refs.splitlines():
        if not line.strip():
            continue
        ref, commit = line.split("\t", 1)
        if ref in (base_ref, f"refs/remotes/{remote}/HEAD"):
            continue
        branch_name = ref.removeprefix(f"refs/remotes/{remote}/")
        try:
            merge_base = _git(repo, "merge-base", base_ref, commit).strip()
        except BranchInboxError:
            continue
        changed = _git(repo, "diff", "--name-only", "--diff-filter=A", merge_base, commit, "--", inbox)
        for path_text in changed.splitlines():
            p = PurePosixPath(path_text)
            parts = p.parts
            prefix = PurePosixPath(inbox).parts
            if len(parts) != len(prefix) + 2 or parts[:len(prefix)] != prefix or parts[-1] != "ready.json":
                continue
            sid = parts[-2]
            if (repo / receipts / f"{sid}.json").exists():
                continue
            sub = BranchSubmission(sid, branch_name, ref, commit, path_text)
            prior = found.get(sid)
            if prior and (prior.commit != sub.commit or prior.ready_path != sub.ready_path):
                raise BranchInboxError(f"submission id appears on multiple branch tips: {sid}")
            found[sid] = sub
    return [found[k] for k in sorted(found)]


def read_ready(repo: Path, sub: BranchSubmission) -> dict:
    raw = _git(Path(repo), "show", f"{sub.commit}:{sub.ready_path}")
    try:
        return json.loads(raw)
    except json.JSONDecodeError as e:
        raise BranchInboxError(f"invalid ready.json on {sub.branch_name}: {e}") from e


def materialize_package(repo: Path, sub: BranchSubmission, package_path: str, dest: Path) -> str:
    """Materialize only the package subtree from a branch commit, without checkout."""
    prefix = PurePosixPath(sub.ready_path).parent / package_path
    if prefix.is_absolute() or ".." in prefix.parts:
        raise BranchInboxError("unsafe package path")
    prefix_text = prefix.as_posix().rstrip("/")
    tar_bytes = _git(Path(repo), "archive", "--format=tar", sub.commit, prefix_text, binary=True)
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:") as tf:
        for member in tf.getmembers():
            mp = PurePosixPath(member.name)
            prefix_path = PurePosixPath(prefix_text)
            if prefix_path == mp or prefix_path.is_relative_to(mp):
                continue
            try:
                rel = mp.relative_to(prefix_path)
            except ValueError as e:
                raise BranchInboxError(f"archive member outside package root: {member.name}") from e
            if not rel.parts:
                continue
            if rel.is_absolute() or ".." in rel.parts:
                raise BranchInboxError(f"unsafe archive member: {member.name}")
            target = dest.joinpath(*rel.parts)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            if not member.isfile():
                raise BranchInboxError(f"unsupported Git package member type: {member.name}")
            target.parent.mkdir(parents=True, exist_ok=True)
            src = tf.extractfile(member)
            if src is None:
                raise BranchInboxError(f"unable to read archive member: {member.name}")
            target.write_bytes(src.read())
            os.chmod(target, member.mode & 0o777)
    return prefix_text
