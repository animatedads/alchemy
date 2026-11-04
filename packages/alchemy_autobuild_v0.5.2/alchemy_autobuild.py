#!/usr/bin/env python3
"""Alchemy Autobuild v0.5.2: keep file modes when a package is unpacked.

Author: Claude (Opus 5.5), 2026-11-04. Architecture: Tom Dyer.

Extends v0.5.1 without modifying it. One change only:

v0.3's extract() used zipfile.extractall(), which ignores the Unix mode
stored in each ZIP entry. Every package therefore ran its tests and was
published with no execute bits. A test whose argv runs a script directly
(["./gopher"], or a run_tests.sh that calls tests/x.sh) failed with
"Permission denied", and a FAIL receipt is final. The published tree on main
also lost the 100755 mode that the producer committed.

The Git branch path already writes the mode into the deterministic snapshot
(v0.3 deterministic_zip_tree, v0.5 materialize_package); only extract()
dropped it. v0.5.2 replaces extract() in the v0.3 engine, which every layer
calls, with a version that applies the stored permission bits (0o777 only, never setuid, setgid or
sticky; owner read/write always kept) to regular files after extraction. The
path-escape check is unchanged.
"""
from __future__ import annotations

import importlib.util
import os
import stat
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def _packages_dir():
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo and (Path(repo) / "packages/alchemy_autobuild_v0.5.1/alchemy_autobuild.py").is_file():
        return Path(repo) / "packages"
    return HERE.parent


V051_PATH = _packages_dir() / "alchemy_autobuild_v0.5.1" / "alchemy_autobuild.py"


def _load_v051():
    if not V051_PATH.is_file():
        raise RuntimeError("alchemy_autobuild_v0.5.1 dependency not found: " + str(V051_PATH))
    spec = importlib.util.spec_from_file_location("alchemy_autobuild_v051_base", V051_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_v051 = _load_v051()
_v3 = _v051._v3


def zip_mode(info):
    """Permission bits stored in a ZIP entry, or None if the entry has none."""
    mode = (info.external_attr >> 16) & 0xFFFF
    if mode == 0:
        return None                      # written without Unix attributes
    if stat.S_IFMT(mode) not in (0, stat.S_IFREG):
        return None                      # symlink or other special entry
    # The runner must still be able to read, rewrite and clean up the file.
    return (mode & 0o777) | 0o600


def extract(z, d):
    """v0.3 extract() with the same path check, plus the stored file modes."""
    d = Path(d)
    with zipfile.ZipFile(z) as f:
        infos = f.infolist()
        for info in infos:
            _v3.safe_path(d, info.filename)
        f.extractall(d)
        for info in infos:
            if info.is_dir():
                continue
            mode = zip_mode(info)
            if mode is None:
                continue
            target = _v3.safe_path(d, info.filename)
            if target.is_file() and not target.is_symlink():
                os.chmod(target, mode)


# Every layer reaches extract() through the v0.3 module globals.
_v3.extract = extract


class Runner(_v051.Runner):
    """v0.5.1 Runner; the state file names this version."""

    def __init__(self, c, start_ns=None):
        super().__init__(c, start_ns)
        _v3.state(c, self.start_ns, "started", intake="all-post-start-zips-oldest-first/0.5.2")


# v0.5.1 loop() constructs Runner through its module globals.
_v051.Runner = Runner

# Re-export the v0.5.1 surface so callers and tests can use this module alone.
loop = _v051.loop
status = _v051.status
load_config = _v051.load_config
list_pending = _v051.list_pending
process_zip = _v051.process_zip
classify = _v051.classify
candidates = _v051.candidates


def main(argv=None):
    return _v051.main(argv)


if __name__ == "__main__":
    sys.exit(main())
