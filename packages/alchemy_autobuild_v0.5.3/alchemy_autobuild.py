#!/usr/bin/env python3
"""Alchemy Autobuild v0.5.3: every package runs the ooRexx Python gate first.

Architecture: Tom Dyer. Coding: Claude (Opus 5.5), 2026-11-14.

Extends v0.5.2 without modifying it. One change only: before a package's own
tests, the runner executes

    rexx packages/oorexx_python_gate_v0.1/bin/python_gate.rex .

in the unpacked package. The gate (ooRexx) fails a package that carries or
calls Python without a PYTHON_JUSTIFICATION entry for it. Its result is
test 01 of the run, with its log in the result and receipt like any other
test, so a FAIL is recorded and nothing is published.

This file is Python only because the running service is Python; see this
package's PYTHON_JUSTIFICATION.

Where it hooks: v0.4 integrate() sets the per-test environment context and
calls v0.3 integrate() through its module global _base_integrate. The ZIP
path (v0.5.1 process_zip -> _v3.integrate) and the branch path (v0.5
_integrate_branch -> v0.4.2 integrate) both pass through that one global, so
v0.5.3 wraps it there. v0.4 matches environment specs to tests by position,
so the wrapper also puts an empty spec in front for the gate.

Config (config.json), all optional:
    python_gate          "enforce" (default) or "advisory" (gate runs and is
                         logged, never fails the package)
    python_gate_script   path to python_gate.rex; default is the copy in the
                         service's own repo checkout
    rexx                 interpreter command; default "rexx"
If the gate script is missing the gate test fails: an unavailable check is
NOT RUN, never PASS.
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GATE_REL = Path("packages/oorexx_python_gate_v0.1/bin/python_gate.rex")
GATE_TEST_NAME = "python-justification-gate"


def _packages_dir():
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo and (Path(repo) / "packages/alchemy_autobuild_v0.5.2/alchemy_autobuild.py").is_file():
        return Path(repo) / "packages"
    return HERE.parent


V052_PATH = _packages_dir() / "alchemy_autobuild_v0.5.2" / "alchemy_autobuild.py"


def _load_v052():
    if not V052_PATH.is_file():
        raise RuntimeError("alchemy_autobuild_v0.5.2 dependency not found: " + str(V052_PATH))
    spec = importlib.util.spec_from_file_location("alchemy_autobuild_v052_base", V052_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_v052 = _load_v052()
_v051 = _v052._v051
_v4 = _v051._base._v4          # v0.4 module: owns _CTX and _base_integrate
_v3 = _v051._v3

_base_load_config = _v051.load_config


def gate_settings(c):
    mode = c.get("python_gate", "enforce")
    if mode not in ("enforce", "advisory"):
        raise ValueError("python_gate must be 'enforce' or 'advisory'")
    script = c.get("python_gate_script") or str(Path(c["repo"]) / GATE_REL)
    rexx = c.get("rexx", "rexx")
    return mode, script, rexx


def gate_test(c):
    mode, script, rexx = gate_settings(c)
    argv = [rexx, script, "."]
    if mode == "advisory":
        argv.append("--advisory")
    return {"name": GATE_TEST_NAME, "argv": argv, "cwd": ".", "timeout_seconds": 300}


_base_integrate = _v4._base_integrate


def integrate_with_gate(z, st, m, c, start_ns, *args, **kwargs):
    """v0.3 integrate() with the gate prepended to the package's tests."""
    gated = dict(m)
    gated["tests"] = [gate_test(c)] + list(m["tests"])
    ctx = _v4._CTX
    if ctx is not None:
        ctx["tests"] = [{}] + list(ctx["tests"])
    return _base_integrate(z, st, gated, c, start_ns, *args, **kwargs)


_v4._base_integrate = integrate_with_gate


def load_config(path=None):
    c = _base_load_config(path)
    c["python_gate"] = "enforce"
    if path:
        x = json.loads(Path(path).read_text())
        for k in ("python_gate", "python_gate_script", "rexx"):
            if k in x:
                c[k] = x[k]
    gate_settings(c)               # reject a bad mode at start, not mid-run
    return c


class Runner(_v052.Runner):
    """v0.5.2 Runner; the state file names this version and the gate mode."""

    def __init__(self, c, start_ns=None):
        super().__init__(c, start_ns)
        mode, script, _ = gate_settings(c)
        _v3.state(c, self.start_ns, "started", intake="all-post-start-zips-oldest-first/0.5.3",
                  python_gate=mode, python_gate_script=script)


# v0.5.1 loop() and main() build Runner and config through their module globals.
_v051.Runner = Runner
_v052.Runner = Runner
_v051.load_config = load_config
_v052.load_config = load_config

loop = _v051.loop
status = _v051.status
list_pending = _v051.list_pending
process_zip = _v051.process_zip
classify = _v051.classify
candidates = _v051.candidates
zip_mode = _v052.zip_mode


def main(argv=None):
    return _v051.main(argv)


if __name__ == "__main__":
    sys.exit(main())
