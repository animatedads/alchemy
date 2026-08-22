#!/usr/bin/env python3
"""Alchemy Autobuild v0.4.2: explicit remote-ref Git synchronization.

Extends v0.4.1 without changing the v0.4 per-test environment contract.
"""
import importlib.util
import os
from pathlib import Path
from git_sync import sync_repo


def _load_v041():
    here = Path(__file__).resolve()
    candidates = []
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo:
        candidates.append(Path(repo) / "packages/alchemy_autobuild_v0.4.1/alchemy_autobuild.py")
    candidates.append(here.parents[1] / "alchemy_autobuild_v0.4.1/alchemy_autobuild.py")
    for path in candidates:
        if path.is_file():
            spec = importlib.util.spec_from_file_location("alchemy_autobuild_v041_base", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    raise RuntimeError("alchemy_autobuild_v0.4.1 dependency not found")


_v041 = _load_v041()
for _name in dir(_v041):
    if not _name.startswith("__") and _name not in globals():
        globals()[_name] = getattr(_v041, _name)

# Patch every layer that can initiate repository synchronization.
_v041.sync_repo = sync_repo
if hasattr(_v041, "_v4"):
    _v041._v4.sync_repo = sync_repo
    if hasattr(_v041._v4, "_v3"):
        _v041._v4._v3.sync_repo = sync_repo


def main():
    return _v041.main()


if __name__ == "__main__":
    main()
