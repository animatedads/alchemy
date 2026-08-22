#!/usr/bin/env python3
"""Alchemy Autobuild v0.4 environment-contract layer.

v0.4 deliberately extends the accepted v0.3 runner instead of duplicating it.
The dependency is explicit: packages/alchemy_autobuild_v0.3 must be present in
ALCHEMY_REPO_ROOT. v0.4 adds per-test environment overlays, first-class
REXX_PATH construction, required-export checks, and environment evidence.
"""
import copy
import importlib.util
import os
import re
import time
from pathlib import Path


def _load_v3():
    here = Path(__file__).resolve()
    candidates = []
    repo = os.environ.get("ALCHEMY_REPO_ROOT")
    if repo:
        candidates.append(Path(repo) / "packages/alchemy_autobuild_v0.3/alchemy_autobuild.py")
    candidates.append(here.parents[1] / "alchemy_autobuild_v0.3/alchemy_autobuild.py")
    for path in candidates:
        if path.is_file():
            spec = importlib.util.spec_from_file_location("alchemy_autobuild_v03_base", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    raise RuntimeError("alchemy_autobuild_v0.3 dependency not found")


_v3 = _load_v3()
_base_validate = _v3.validate
_base_run = _v3.run
_base_integrate = _v3.integrate
for _name in dir(_v3):
    if not _name.startswith("__") and _name not in globals():
        globals()[_name] = getattr(_v3, _name)

SCHEMA_V1 = _v3.SCHEMA_V1
SCHEMA_V2 = _v3.SCHEMA
SCHEMA = "alchemy.autobuild.integration/0.3"
SUPPORTED_SCHEMAS = set(_v3.SUPPORTED_SCHEMAS) | {SCHEMA}
RESULT_SCHEMA = "alchemy.autobuild.result/0.4"
MSG_SCHEMA = "alchemy.mesh.autobuild/0.4"
_TOKEN = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
_CTX = None


def _validate_env_spec(spec, label):
    if spec is None:
        return
    if not isinstance(spec, dict):
        raise ValueError(f"{label} must be object")
    if not isinstance(spec.get("set", {}), dict) or not all(isinstance(k, str) and k and isinstance(v, str) for k, v in spec.get("set", {}).items()):
        raise ValueError(f"{label}.set must map non-empty names to strings")
    for key in ("prepend_path", "append_path", "require", "require_dirs", "report"):
        value = spec.get(key, [])
        if not isinstance(value, list) or not all(isinstance(x, str) and x for x in value):
            raise ValueError(f"{label}.{key} must be an array of non-empty strings")
    rp = spec.get("rexx_path")
    if rp is not None:
        if not isinstance(rp, dict):
            raise ValueError(f"{label}.rexx_path must be object")
        if rp.get("mode", "replace") not in ("replace", "prepend", "append"):
            raise ValueError(f"{label}.rexx_path.mode must be replace, prepend, or append")
        entries = rp.get("entries", [])
        if not isinstance(entries, list) or not all(isinstance(x, str) and x for x in entries):
            raise ValueError(f"{label}.rexx_path.entries must be an array of non-empty strings")
        if "require_entries" in rp and not isinstance(rp["require_entries"], bool):
            raise ValueError(f"{label}.rexx_path.require_entries must be boolean")


def validate(m):
    if not isinstance(m, dict) or m.get("schema") not in SUPPORTED_SCHEMAS:
        raise ValueError("unsupported integration schema")
    base = copy.deepcopy(m)
    if base.get("schema") == SCHEMA:
        base["schema"] = SCHEMA_V2
    _base_validate(base)
    _validate_env_spec(m.get("environment", {}), "environment")
    for i, test in enumerate(m.get("tests", []), 1):
        _validate_env_spec(test.get("environment", {}), f"tests[{i}].environment")


def _expand(value, env, pkg, c):
    mapping = dict(env)
    mapping.update(PACKAGE_ROOT=str(pkg), AUTOBUILD_ROOT=str(c["root"]), REPO_ROOT=str(c["repo"]))
    text = value
    for _ in range(8):
        newer = _TOKEN.sub(lambda m: mapping.get(m.group(1), m.group(0)), text)
        if newer == text:
            break
        text = newer
        mapping.update(env)
    unresolved = _TOKEN.findall(text)
    if unresolved:
        raise ValueError("unresolved environment token(s): " + ",".join(sorted(set(unresolved))))
    return text


def _path_item(value, env, pkg, c):
    text = _expand(value, env, pkg, c)
    p = Path(text).expanduser()
    if p.is_absolute():
        return str(p)
    return str(_v3.safe_path(pkg, p))


def _apply_environment(base, spec, pkg, c):
    e = dict(base)
    for key, raw in spec.get("set", {}).items():
        e[key] = _expand(raw, e, pkg, c)
    pre = [_path_item(x, e, pkg, c) for x in spec.get("prepend_path", [])]
    app = [_path_item(x, e, pkg, c) for x in spec.get("append_path", [])]
    if pre or app:
        old = [e.get("PATH", "")] if e.get("PATH") else []
        e["PATH"] = os.pathsep.join(pre + old + app)
    rp = spec.get("rexx_path")
    if rp is not None:
        entries = [_path_item(x, e, pkg, c) for x in rp.get("entries", [])]
        old = e.get("REXX_PATH", "")
        mode = rp.get("mode", "replace")
        if mode == "replace":
            parts = entries
        elif mode == "prepend":
            parts = entries + ([old] if old else [])
        else:
            parts = ([old] if old else []) + entries
        e["REXX_PATH"] = os.pathsep.join(parts)
    e.update(ALCHEMY_PACKAGE_ROOT=str(pkg), ALCHEMY_AUTOBUILD_ROOT=str(c["root"]), ALCHEMY_REPO_ROOT=str(c["repo"]))
    return e


def environment(spec, pkg, c):
    return _apply_environment(os.environ.copy(), spec, pkg, c)


def _requirements(specs, env, pkg, c):
    errors = []
    for spec in specs:
        for name in spec.get("require", []):
            if not env.get(name):
                errors.append(f"required environment variable missing: {name}")
        for name in spec.get("require_dirs", []):
            value = env.get(name)
            if not value:
                errors.append(f"required directory export missing: {name}")
            elif not Path(value).is_dir():
                errors.append(f"required directory export is not a directory: {name}={value}")
        rp = spec.get("rexx_path")
        if rp and rp.get("require_entries"):
            for raw in rp.get("entries", []):
                path = _path_item(raw, env, pkg, c)
                if not Path(path).is_dir():
                    errors.append(f"REXX_PATH entry is not a directory: {path}")
    return errors


def _evidence(specs, env):
    names = {"PATH", "REXX_PATH", "ALCHEMY_PACKAGE_ROOT", "ALCHEMY_REPO_ROOT"}
    for spec in specs:
        names.update(spec.get("report", []))
        names.update(spec.get("require", []))
        names.update(spec.get("require_dirs", []))
    return {name: env.get(name) for name in sorted(names)}


def _failed_env_result(argv, message, evidence):
    now = time.time_ns()
    return dict(argv=argv, returncode=125, timed_out=False, stdout="", stderr="AUTOBUILD_ENV_CONTRACT: " + message + "\n", started_at=_v3.iso(now), ended_at=_v3.iso(now), elapsed_ms=0.0, environment=evidence)


def _patched_run(argv, cwd=None, env=None, timeout=None):
    global _CTX
    if _CTX is None:
        return _base_run(argv, cwd, env, timeout)
    index = _CTX["index"]
    _CTX["index"] += 1
    test_spec = _CTX["tests"][index] if index < len(_CTX["tests"]) else {}
    package_spec = _CTX["package"]
    pkg = Path(env["ALCHEMY_PACKAGE_ROOT"])
    c = {"root": Path(env["ALCHEMY_AUTOBUILD_ROOT"]), "repo": Path(env["ALCHEMY_REPO_ROOT"])}
    effective = _apply_environment(env, test_spec, pkg, c)
    specs = (package_spec, test_spec)
    evidence = _evidence(specs, effective)
    errors = _requirements(specs, effective, pkg, c)
    if errors:
        return _failed_env_result(argv, "; ".join(errors), evidence)
    result = _base_run(argv, cwd, effective, timeout)
    result["environment"] = evidence
    return result


def integrate(z, st, m, c, start_ns, source_meta=None, sync=True, receipt=None, run_tag=None):
    global _CTX
    previous = _CTX
    _CTX = {"package": m.get("environment", {}), "tests": [t.get("environment", {}) for t in m.get("tests", [])], "index": 0}
    try:
        return _base_integrate(z, st, m, c, start_ns, source_meta, sync, receipt, run_tag)
    finally:
        _CTX = previous


_v3.validate = validate
_v3.environment = environment
_v3.run = _patched_run
_v3.integrate = integrate
_v3.SUPPORTED_SCHEMAS = SUPPORTED_SCHEMAS
_v3.RESULT_SCHEMA = RESULT_SCHEMA
_v3.MSG_SCHEMA = MSG_SCHEMA


def main():
    return _v3.main()


if __name__ == "__main__":
    main()
