#!/usr/bin/env python3
"""Lossless Python runtime class-surface introspector for Semantic Source Control."""
from __future__ import annotations
import inspect, json, platform, sys


def member_kind(raw):
    if isinstance(raw, classmethod): return "CLASSMETHOD"
    if isinstance(raw, staticmethod): return "STATICMETHOD"
    if isinstance(raw, property): return "PROPERTY"
    if inspect.isfunction(raw): return "METHOD"
    if callable(raw): return "CALLABLE"
    return ""


def inspect_class(cls):
    groups = {}
    order = []
    for depth, scope in enumerate(cls.__mro__):
        for name, raw in scope.__dict__.items():
            kind = member_kind(raw)
            if not kind:
                continue
            if name not in groups:
                groups[name] = []
                order.append(name)
            groups[name].append({
                "name": name,
                "source_spelling": name,
                "runtime_spelling": name,
                "lookup_key": name,
                "kind": kind,
                "origin_class": scope.__name__,
                "origin_module": scope.__module__,
                "depth": depth,
            })
    surface=[]
    for name in order:
        editions=groups[name]
        for i,e in enumerate(editions):
            row=dict(e)
            row["is_effective"] = 1 if i == 0 else 0
            row["relation_kind"] = "DECLARED" if i == 0 and e["origin_class"] == cls.__name__ else ("INHERITED" if i == 0 else "SHADOWED")
            if i == 0 and len(editions) > 1 and e["origin_class"] == cls.__name__:
                row["relation_kind"]="OVERRIDES"
                row["overrides_class"] = editions[1]["origin_class"]
            surface.append(row)
    return {
        "runtime":"Python",
        "runtime_version":platform.python_version(),
        "module":cls.__module__,
        "class_name":cls.__name__,
        "mro":[c.__name__ for c in cls.__mro__],
        "method_surface":surface,
    }

if __name__ == '__main__':
    print(json.dumps({"tool":"semantic-source.python-runtime-introspector/1","python":platform.python_version()}))
