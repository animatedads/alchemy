"""Tiny method-profile projection layer for the ooRexx/Python POC.

Profiles describe capability, not object identity.  Discovery is conservative:
public callable instance/class methods are inspected, annotations are advisory,
and explicit settings may override or completely replace discovery.
"""
from __future__ import annotations

import hashlib
import inspect
import json


def _annotation_name(value):
    if value is inspect.Signature.empty:
        return None
    if value is None or value is type(None):
        return "none"
    if isinstance(value, str):
        return value
    return getattr(value, "__name__", repr(value))


def _method_entry(name, callable_obj):
    sig = inspect.signature(callable_obj)
    args = []
    required = 0
    variadic = False
    for p in sig.parameters.values():
        if p.kind in (p.VAR_POSITIONAL, p.VAR_KEYWORD):
            variadic = True
            continue
        if p.kind in (p.POSITIONAL_ONLY, p.POSITIONAL_OR_KEYWORD):
            args.append(_annotation_name(p.annotation))
            if p.default is p.empty:
                required += 1
    return {
        "python": name,
        "min_args": required,
        "max_args": None if variadic else len(args),
        "args": args,
        "returns": _annotation_name(sig.return_annotation),
        "source": "discovered",
    }


def discover_profile(obj):
    methods = {}
    for name in dir(obj):
        if name.startswith("_"):
            continue
        try:
            member = getattr(obj, name)
        except Exception:
            continue
        if callable(member):
            try:
                entry = _method_entry(name, member)
            except (TypeError, ValueError):
                continue
            methods[name.upper()] = entry
    return {"methods": methods}


def _normalise_for_fingerprint(profile):
    # Python spelling is intentionally excluded: the fingerprint represents the
    # Rexx-visible capability shape, while casing/spelling remains projection metadata.
    out = {}
    for rexx_name, entry in sorted(profile["methods"].items()):
        out[rexx_name] = {
            "min_args": entry.get("min_args"),
            "max_args": entry.get("max_args"),
            "args": entry.get("args"),
            "returns": entry.get("returns"),
        }
    return out


def profile_fingerprint(profile):
    encoded = json.dumps(_normalise_for_fingerprint(profile), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(encoded.encode()).hexdigest()[:16]


def make_profile(obj, settings=None, mode="discover"):
    """Build a profile in discover, override, or forced mode.

    settings is a mapping of Rexx message names to dictionaries.  At minimum a
    forced entry needs ``python``.  Other fields can pin arity/argument/return
    expectations for documentation and later enforcement.
    """
    if mode not in ("discover", "override", "forced"):
        raise ValueError("mode must be discover, override, or forced")
    settings = settings or {}
    profile = {"methods": {}} if mode == "forced" else discover_profile(obj)

    for rexx_name, supplied in settings.items():
        if not isinstance(supplied, dict):
            supplied = {"python": supplied}
        key = rexx_name.upper()
        base = dict(profile["methods"].get(key, {}))
        base.update(supplied)
        base["source"] = "forced" if mode == "forced" else "override"
        if "python" not in base:
            raise ValueError(f"profile entry {key} has no Python method")
        member = getattr(obj, base["python"], None)
        if not callable(member):
            raise AttributeError(f"{type(obj).__name__}.{base['python']} is not callable")
        profile["methods"][key] = base

    profile["mode"] = mode
    profile["fingerprint"] = profile_fingerprint(profile)
    return profile


def casing_map(profile):
    return {rexx: entry["python"] for rexx, entry in profile["methods"].items()}


def wrap_projected(native, obj, factory, settings=None, mode="discover"):
    profile = make_profile(obj, settings=settings, mode=mode)
    proxy, handle = native.wrap_python_object(obj, factory, casing_map(profile))
    return proxy, handle, profile
