#!/usr/bin/env python3
"""Canonical AI sender for Alchemy Autobuild Git submissions.

Creates an immutable submission branch containing:

  autobuild/inbox/<submission-id>/package/...
  autobuild/inbox/<submission-id>/ready.json

The package body and ready marker are separate commits, but both are transferred in
one push. The caller's current checkout is never switched: a temporary worktree is
used from the current remote-tracking base branch.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from secrets import token_hex

READY_SCHEMA = "alchemy.autobuild.git-submission/0.1"
SUPPORTED_INTEGRATION_SCHEMAS = {
    "alchemy.autobuild.integration/0.1",
    "alchemy.autobuild.integration/0.2",
    "alchemy.autobuild.integration/0.3",
}
_SAFE = re.compile(r"[^A-Za-z0-9._-]+")


class SubmitError(RuntimeError):
    pass


def run(argv, *, cwd=None, capture=True):
    try:
        cp = subprocess.run(
            argv,
            cwd=cwd,
            text=True,
            check=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except subprocess.CalledProcessError as e:
        detail = (e.stderr or e.stdout or "").strip()
        raise SubmitError(
            f"command failed ({e.returncode}): {' '.join(argv)}"
            + (f"\n{detail}" if detail else "")
        ) from e
    return (cp.stdout or "").strip()


def slug(value: str, *, fallback: str = "submission", limit: int = 80) -> str:
    out = _SAFE.sub("-", value.strip()).strip("-._")
    if not out:
        out = fallback
    return out[:limit]


def validate_package(package: Path) -> dict:
    package = package.resolve()
    if not package.is_dir():
        raise SubmitError(f"package directory does not exist: {package}")
    manifest_path = package / "integration.json"
    if not manifest_path.is_file():
        raise SubmitError("package must contain integration.json at its root")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except Exception as e:
        raise SubmitError(f"invalid integration.json: {e}") from e
    if manifest.get("schema") not in SUPPORTED_INTEGRATION_SCHEMAS:
        raise SubmitError(
            f"unsupported integration schema: {manifest.get('schema')!r}"
        )
    pkg = manifest.get("package")
    if not isinstance(pkg, dict) or not pkg.get("name") or not pkg.get("version"):
        raise SubmitError("integration.json requires package.name and package.version")
    tests = manifest.get("tests")
    if not isinstance(tests, list) or not tests:
        raise SubmitError("integration.json requires at least one declared test")
    for path in package.rglob("*"):
        if path.is_symlink():
            raise SubmitError(
                "symlinks are not allowed in submission packages: "
                + str(path.relative_to(package))
            )
    return manifest


def copy_package(src: Path, dst: Path) -> None:
    def ignore(directory, names):
        # Nested Git metadata is not package source. Everything else is copied
        # byte-for-byte; there is intentionally no source-file heuristic.
        return {".git"} if ".git" in names else set()

    shutil.copytree(src, dst, symlinks=False, ignore=ignore)


def ensure_repo(repo: Path) -> None:
    if run(["git", "-C", str(repo), "rev-parse", "--is-inside-work-tree"]) != "true":
        raise SubmitError(f"not a Git worktree: {repo}")


def build_ids(
    manifest: dict,
    submitted_by: str,
    label: str | None,
    submission_id: str | None,
):
    now = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    producer = slug(submitted_by, fallback="AI", limit=24).upper()
    pkg = manifest["package"]
    base_label = label or f"{pkg['name']}-v{pkg['version']}"
    task = slug(base_label, fallback="package", limit=64)
    sid = submission_id or f"{now}-{producer}-{task}-{token_hex(3)}"
    sid = slug(sid, fallback="submission", limit=120)
    branch = f"autobuild-submit/{sid}"
    return sid, branch


def submit(
    *,
    repo: Path,
    package: Path,
    submitted_by: str,
    remote: str,
    base: str,
    label: str | None = None,
    submission_id: str | None = None,
    dry_run: bool = False,
) -> dict:
    repo = repo.resolve()
    package = package.resolve()
    ensure_repo(repo)
    manifest = validate_package(package)
    sid, branch = build_ids(manifest, submitted_by, label, submission_id)
    inbox_rel = Path("autobuild/inbox") / sid
    package_rel = inbox_rel / "package"
    ready_rel = inbox_rel / "ready.json"
    remote_ref = f"refs/remotes/{remote}/{base}"
    refspec = f"+refs/heads/{base}:{remote_ref}"

    if dry_run:
        return {
            "status": "DRY_RUN",
            "submission_id": sid,
            "branch": branch,
            "package": manifest["package"],
            "package_path": package_rel.as_posix(),
            "ready_path": ready_rel.as_posix(),
            "pushes": 0,
            "planned_pushes": 1,
        }

    # Fetch one exact base ref. Do not use git pull or FETCH_HEAD.
    run(["git", "-C", str(repo), "fetch", remote, refspec])
    run(["git", "-C", str(repo), "rev-parse", "--verify", remote_ref])

    temp_root = Path(tempfile.mkdtemp(prefix="alchemy-submit-"))
    worktree = temp_root / "worktree"
    local_branch = f"alchemy-submit-{slug(sid, limit=80)}"
    added_worktree = False
    try:
        run(
            [
                "git",
                "-C",
                str(repo),
                "worktree",
                "add",
                "--detach",
                str(worktree),
                remote_ref,
            ]
        )
        added_worktree = True
        run(["git", "-C", str(worktree), "switch", "-c", local_branch])

        target_pkg = worktree / package_rel
        target_pkg.parent.mkdir(parents=True, exist_ok=False)
        copy_package(package, target_pkg)
        run(["git", "-C", str(worktree), "add", "--", package_rel.as_posix()])
        run(
            [
                "git",
                "-C",
                str(worktree),
                "commit",
                "-m",
                f"autobuild submission: stage {sid}",
            ]
        )
        package_commit = run(["git", "-C", str(worktree), "rev-parse", "HEAD"])

        ready = {
            "schema": READY_SCHEMA,
            "submission_id": sid,
            "submitted_by": submitted_by,
            "package_path": "package",
        }
        ready_path = worktree / ready_rel
        ready_path.write_text(
            json.dumps(ready, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        run(["git", "-C", str(worktree), "add", "--", ready_rel.as_posix()])
        run(
            [
                "git",
                "-C",
                str(worktree),
                "commit",
                "-m",
                f"autobuild submission: ready {sid}",
            ]
        )
        ready_commit = run(["git", "-C", str(worktree), "rev-parse", "HEAD"])

        # One push transfers both commits and all package objects in one pack.
        run(
            [
                "git",
                "-C",
                str(worktree),
                "push",
                remote,
                f"HEAD:refs/heads/{branch}",
            ]
        )

        return {
            "status": "SUBMITTED",
            "submission_id": sid,
            "branch": branch,
            "submitted_by": submitted_by,
            "package": manifest["package"],
            "package_path": package_rel.as_posix(),
            "ready_path": ready_rel.as_posix(),
            "package_commit": package_commit,
            "ready_commit": ready_commit,
            "base_ref": remote_ref,
            "pushes": 1,
        }
    finally:
        if added_worktree:
            try:
                run(
                    [
                        "git",
                        "-C",
                        str(repo),
                        "worktree",
                        "remove",
                        "--force",
                        str(worktree),
                    ]
                )
            except Exception:
                pass
        shutil.rmtree(temp_root, ignore_errors=True)
        try:
            run(["git", "-C", str(repo), "branch", "-D", local_branch])
        except Exception:
            pass


def main(argv=None) -> int:
    p = argparse.ArgumentParser(
        description="Submit one Alchemy Autobuild package through a durable Git branch"
    )
    p.add_argument(
        "--package",
        required=True,
        type=Path,
        help="package directory containing root integration.json",
    )
    p.add_argument(
        "--submitted-by",
        required=True,
        help="producer identity, e.g. CHATGPT or CLAUDE",
    )
    p.add_argument(
        "--repo",
        type=Path,
        default=Path.cwd(),
        help="local clone of animatedads/alchemy (default: cwd)",
    )
    p.add_argument("--remote", default="origin")
    p.add_argument("--base", default="main")
    p.add_argument("--label", help="short label used in generated submission id")
    p.add_argument(
        "--submission-id", help="explicit globally unique id (normally omit)"
    )
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--json", action="store_true", help="emit machine-readable result")
    ns = p.parse_args(argv)
    try:
        result = submit(
            repo=ns.repo,
            package=ns.package,
            submitted_by=ns.submitted_by,
            remote=ns.remote,
            base=ns.base,
            label=ns.label,
            submission_id=ns.submission_id,
            dry_run=ns.dry_run,
        )
    except SubmitError as e:
        if ns.json:
            print(json.dumps({"status": "ERROR", "error": str(e)}, sort_keys=True))
        else:
            print(f"ERROR: {e}", file=sys.stderr)
        return 2
    if ns.json:
        print(json.dumps(result, sort_keys=True))
    else:
        print(
            f"{result['status']} submission_id={result['submission_id']} "
            f"branch={result['branch']} pushes={result.get('pushes', 0)}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
