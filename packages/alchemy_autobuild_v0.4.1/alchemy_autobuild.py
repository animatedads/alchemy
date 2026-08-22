#!/usr/bin/env python3
"""Alchemy Autobuild v0.4.1: unambiguous Git fast-forward sync.

Extends v0.4 without changing its per-test environment contract.
"""
import importlib.util
import os
from pathlib import Path
from git_sync import sync_repo


def _load_v4():
    here = Path(__file__).resolve()
    candidates = []
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo:
        candidates.append(Path(repo) / "packages/alchemy_autobuild_v0.4/alchemy_autobuild.py")
    candidates.append(here.parents[1] / "alchemy_autobuild_v0.4/alchemy_autobuild.py")
    for path in candidates:
        if path.is_file():
            spec = importlib.util.spec_from_file_location("alchemy_autobuild_v04_base", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    raise RuntimeError("alchemy_autobuild_v0.4 dependency not found")


_v4 = _load_v4()
for _name in dir(_v4):
    if not _name.startswith("__") and _name not in globals():
        globals()[_name] = getattr(_v4, _name)

# v0.4 delegates its event loop and integration engine to the accepted v0.3
# module, so patch the synchronization hook at both visible levels.
_v4.sync_repo = sync_repo
_v4._v3.sync_repo = sync_repo


def main():
    return _v4.main()


if __name__ == "__main__":
    main()
