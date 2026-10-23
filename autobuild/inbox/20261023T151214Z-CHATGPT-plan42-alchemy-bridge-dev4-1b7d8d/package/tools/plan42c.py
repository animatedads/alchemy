#!/usr/bin/env python3
"""
plan42c.py

Ouroboros compiler for Plan42 program specifications.

Current production backend: Python 3.
Registered future backend slots: Rust, ooRexx, C++, Java, Bash.

The compiler is intentionally backend-oriented rather than Python-special-case
spaghetti.  Plan42 nodes are lowered through a Backend interface.  Language
escape hatches (`impl` / `impl_use`) are resolved through an ImplRegistry so
round-tripped real programs can keep their host-language detail while the
portable Plan42 structure remains visible.
"""

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import subprocess
import sys
import textwrap
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Optional

PLAN42_SPEC_VERSION = "1.1"
PYTHON_TARGETS = {"python", "python3", "py"}
KNOWN_TARGETS = {"python", "python3", "py", "rust", "oorexx", "oo-rexx", "oo_rexx", "orx", "classicrexx", "classic-rexx", "classic_rexx", "regina", "rexx", "c", "c11", "cpp", "c++", "java", "bash", "sh"}


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError("Plan42 input must be a JSON object")
    return data


def write_text(path: Optional[Path], text: str) -> None:
    if path is None or str(path) == "-":
        sys.stdout.write(text)
        if text and not text.endswith("\n"):
            sys.stdout.write("\n")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def py_name(value: Any, *, fallback: str = "_p42_value") -> str:
    """Return a safe Python identifier derived from arbitrary Plan42 text.

    Leading/trailing underscores are preserved.  That matters for Python
    protocol methods such as ``__init__`` and is also useful for generated
    helper names.
    """
    s = str(value if value is not None and value != "" else fallback)
    s = re.sub(r"[^0-9A-Za-z_]", "_", s)
    if not s or set(s) == {"_"}:
        s = fallback or "p42_value"
        s = re.sub(r"[^0-9A-Za-z_]", "_", s)
    if s[0].isdigit():
        s = "_" + s
    if s in PYTHON_KEYWORDS:
        s += "_"
    return s


PYTHON_KEYWORDS = {
    "False", "None", "True", "and", "as", "assert", "async", "await", "break",
    "class", "continue", "def", "del", "elif", "else", "except", "finally",
    "for", "from", "global", "if", "import", "in", "is", "lambda", "nonlocal",
    "not", "or", "pass", "raise", "return", "try", "while", "with", "yield",
}



def normalise_inline_block(code: str) -> str:
    """Remove source-file indentation from an inline Python block.

    ast.get_source_segment can return a first line with no indentation while
    preserving absolute indentation on following lines.  We try several tail
    dedents and keep the first one that parses as Python.
    """
    raw = code.strip("\n")
    if not raw.strip():
        return ""
    lines = raw.splitlines()
    first = lines[0].lstrip()
    if len(lines) == 1:
        return first.strip()

    rest = lines[1:]

    def lead_count(line: str) -> int:
        return len(line) - len(line.lstrip(" "))

    leads = sorted({lead_count(line) for line in rest if line.strip()})
    candidates: list[str] = []
    candidates.append(textwrap.dedent(raw).strip())
    for remove in leads:
        new_rest = []
        for line in rest:
            if not line.strip():
                new_rest.append("")
            elif line.startswith(" " * remove):
                new_rest.append(line[remove:])
            else:
                new_rest.append(line.lstrip())
        candidates.append("\n".join([first] + new_rest).strip())
    for remove in leads:
        adjusted = max(0, remove - 4)
        new_rest = []
        for line in rest:
            if not line.strip():
                new_rest.append("")
            elif line.startswith(" " * adjusted):
                new_rest.append(line[adjusted:])
            else:
                new_rest.append(line.lstrip())
        candidates.append("\n".join([first] + new_rest).strip())

    seen = set()
    for cand in candidates:
        if cand in seen:
            continue
        seen.add(cand)
        try:
            ast.parse(cand)
            return cand
        except SyntaxError:
            pass
    # Last resort: keep the first line and comment the raw remainder so the
    # generated file remains parseable instead of failing the whole compiler.
    commented = [first]
    commented.extend("# raw: " + line.lstrip() for line in rest if line.strip())
    return "\n".join(commented).strip()

def is_expr_like_source(src: str) -> bool:
    """True when inline Python source can safely be returned as an expression."""
    stripped = src.strip()
    if not stripped or "\n" in stripped:
        return False
    try:
        ast.parse(stripped, mode="eval")
        return True
    except SyntaxError:
        return False


def indent_lines(lines: Iterable[str], prefix: str) -> list[str]:
    return [prefix + line if line else prefix.rstrip() for line in lines]


def json_literal(value: Any) -> str:
    return repr(value)


PLAN42_PY_TYPE_NAMES = {
    "str": "str",
    "int": "int",
    "float": "float",
    "bool": "bool",
    "list": "list",
    "dict": "dict",
    "any": "Any",
    "object": "Any",
}


def canonical_type_name(value: Any) -> str:
    """Return a normalised lightweight Plan42 type name."""
    if value is None:
        return ""
    text = str(value).strip().lower()
    aliases = {
        "string": "str", "text": "str", "char*": "str",
        "integer": "int", "long": "int",
        "double": "float", "number": "float",
        "boolean": "bool",
        "array": "list", "tuple": "list",
        "map": "dict", "directory": "dict", "hash": "dict",
    }
    return aliases.get(text, text)


def py_type_annotation(value: Any) -> str:
    typ = canonical_type_name(value)
    return PLAN42_PY_TYPE_NAMES.get(typ, "Any") if typ else "Any"


def typed_default_expr(value: Any) -> str:
    typ = canonical_type_name(value)
    if typ == "str":
        return "''"
    if typ == "int":
        return "0"
    if typ == "float":
        return "0.0"
    if typ == "bool":
        return "False"
    if typ == "list":
        return "[]"
    if typ == "dict":
        return "{}"
    return "None"


def plan42_name(value: Any) -> str:
    """Render a Plan42 variable reference name for Python.

    ``var`` nodes should be identifier-like, but existing Plan42 specs used
    bare strings for dotted attributes and other source-ish references.  Keep
    simple dotted references readable while still sanitising each segment.
    """
    text = str(value if value is not None else "_")
    if "." in text and all(part and re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", part) for part in text.split(".")):
        return ".".join(py_name(part) for part in text.split("."))
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", text):
        return py_name(text)
    return text


def normalise_target(target: str) -> str:
    t = target.strip().lower()
    if t in {"c11"}:
        return "c"
    if t == "c++":
        return "cpp"
    if t in {"oorexx", "oo-rexx", "oo_rexx", "orx"}:
        return "oorexx"
    if t in {"classic-rexx", "classic_rexx", "classicrexx", "regina", "rexx"}:
        return "classicrexx"
    if t == "sh":
        return "bash"
    if t == "py":
        return "python3"
    if t == "python":
        return "python3"
    return t


def node_list(value: Any) -> list[dict[str, Any]]:
    if isinstance(value, list):
        return [x for x in value if isinstance(x, dict)]
    return []


# ---------------------------------------------------------------------------
# Validation and indexes
# ---------------------------------------------------------------------------


@dataclass
class CompileDiagnostics:
    warnings: list[str] = field(default_factory=list)
    unresolved_impls: list[str] = field(default_factory=list)
    emitted_nodes: int = 0
    emitted_impl_helpers: int = 0

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def as_dict(self) -> dict[str, Any]:
        return {
            "warnings": self.warnings,
            "unresolved_impls": self.unresolved_impls,
            "emitted_nodes": self.emitted_nodes,
            "emitted_impl_helpers": self.emitted_impl_helpers,
        }


@dataclass
class ImplDefinition:
    name: str
    params: list[str]
    abstract: str
    implementations: dict[str, Any]
    node: dict[str, Any]

    def implementation_for(self, language: str) -> Optional[dict[str, Any]]:
        aliases = [language]
        if language == "python3":
            aliases.extend(["python", "py"])
        elif language == "oorexx":
            aliases.extend(["rexx"])
        elif language == "cpp":
            aliases.extend(["c++"])
        for key in aliases:
            val = self.implementations.get(key)
            if isinstance(val, dict):
                return val
        # Case-insensitive fallback because some older specs use PYTHON3.
        upper_langs = {k.upper(): v for k, v in self.implementations.items() if isinstance(v, dict)}
        for key in aliases:
            val = upper_langs.get(key.upper())
            if isinstance(val, dict):
                return val
        return None


class Plan42Program:
    def __init__(self, spec: dict[str, Any]) -> None:
        self.spec = spec
        self.nodes: list[dict[str, Any]] = node_list(spec.get("nodes"))
        self.impls: dict[str, ImplDefinition] = {}
        self.routines: set[str] = set()
        self.classes: set[str] = set()
        self.constants: set[str] = set()
        self._index()

    def _index(self) -> None:
        for node in self.nodes:
            op = str(node.get("op", "")).lower()
            name = str(node.get("name", ""))
            if op == "impl" and name:
                params = node.get("params") if isinstance(node.get("params"), list) else []
                impls = node.get("implementations") if isinstance(node.get("implementations"), dict) else {}
                self.impls[name] = ImplDefinition(
                    name=name,
                    params=[str(p) for p in params],
                    abstract=str(node.get("abstract", "")),
                    implementations=impls,
                    node=node,
                )
            elif op == "routine" and name:
                self.routines.add(name)
            elif op == "class" and name:
                self.classes.add(name)
            elif op == "const" and name:
                self.constants.add(name)

    def validate(self) -> None:
        if not isinstance(self.spec, dict):
            raise ValueError("Plan42 spec must be a JSON object")
        if str(self.spec.get("spec", PLAN42_SPEC_VERSION)) not in {"1.0", "1.1", PLAN42_SPEC_VERSION}:
            raise ValueError(f"unsupported Plan42 spec version: {self.spec.get('spec')!r}")
        if not self.spec.get("module"):
            raise ValueError("Plan42 spec requires a module name")
        if not isinstance(self.spec.get("nodes"), list):
            raise ValueError("Plan42 spec requires nodes[]")

    def feature_summary(self) -> dict[str, Any]:
        return {
            "module": self.spec.get("module"),
            "node_count": len(self.nodes),
            "routines": sorted(self.routines),
            "classes": sorted(self.classes),
            "constants": sorted(self.constants),
            "impls": sorted(self.impls),
        }


# ---------------------------------------------------------------------------
# Backend interface
# ---------------------------------------------------------------------------


class Backend:
    language = "generic"
    file_extension = ".txt"

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        self.program = program
        self.include_runtime = include_runtime
        self.diagnostics = CompileDiagnostics()
        self.lines: list[str] = []
        self.indent = 0

    def compile(self) -> str:
        raise NotImplementedError

    def emit_line(self, line: str = "") -> None:
        self.lines.append(("    " * self.indent) + line if line else "")

    def emit_block(self, nodes: list[dict[str, Any]]) -> None:
        if not nodes:
            self.emit_line("pass")
            return
        before = len(self.lines)
        for node in nodes:
            self.emit_node(node)
        if len(self.lines) == before:
            self.emit_line("pass")

    def emit_node(self, node: dict[str, Any]) -> None:
        raise NotImplementedError

    def expr(self, value: Any) -> str:
        raise NotImplementedError


class UnsupportedBackend(Backend):
    language = "unsupported"

    def compile(self) -> str:
        raise NotImplementedError(
            f"{self.language} backend is registered but not implemented yet. "
            "The compiler architecture is ready; only the Python3 backend is production-ready in this drop."
        )


class RustBackend(Backend):
    """Plan42 -> Rust scaffold backend.

    This is intentionally a conservative scaffold, not the final Rust lane.  It
    gives Plan42 a real Python-side Rust emitter for typed, safe, boring nodes so
    the target is no longer a hollow registration.  Anything outside that subset
    is emitted as an explicit diagnostic/comment instead of being guessed.
    """

    language = "rust"
    file_extension = ".rs"

    RUST_KEYWORDS = {
        "as", "break", "const", "continue", "crate", "else", "enum", "extern",
        "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod",
        "move", "mut", "pub", "ref", "return", "self", "Self", "static", "struct",
        "super", "trait", "true", "type", "unsafe", "use", "where", "while", "async",
        "await", "dyn",
    }

    BINOPS = {
        "add": "+", "sub": "-", "mul": "*", "div": "/", "mod": "%",
        "eq": "==", "neq": "!=", "lt": "<", "lte": "<=", "gt": ">", "gte": ">=",
        "and": "&&", "or": "||",
    }

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        super().__init__(program, include_runtime=include_runtime)
        self.var_types: dict[str, str] = {}
        self._seed_types()

    def _seed_types(self) -> None:
        for node in self.program.nodes:
            if not isinstance(node, dict):
                continue
            op = str(node.get("op", "")).lower()
            if op in {"const", "declare", "assign"} and node.get("name"):
                typ = canonical_type_name(node.get("type")) or self.infer_type(node.get("value", node.get("expr")))
                if typ:
                    self.var_types[str(node.get("name"))] = typ
            if op == "routine":
                ptypes = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
                for pname, ptype in ptypes.items():
                    self.var_types[str(pname)] = canonical_type_name(ptype) or "str"

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        module = str(self.program.spec.get("module", "Plan42Module"))
        self.emit_line("// Generated from Plan42 by plan42c.py -- Rust scaffold target")
        self.emit_line("// Module: " + self.safe_comment(module))
        self._emit_embedded_spec_comments()
        self.emit_line("#![allow(dead_code)]")
        self.emit_line("#![allow(unused_variables)]")
        self.emit_line("#![allow(unused_mut)]")
        self.emit_line()
        for node in self.program.nodes:
            if isinstance(node, dict) and str(node.get("op", "")).lower() == "const":
                self.emit_const(node)
        if any(isinstance(n, dict) and str(n.get("op", "")).lower() == "const" for n in self.program.nodes):
            self.emit_line()
        for node in self.program.nodes:
            if not isinstance(node, dict):
                continue
            op = str(node.get("op", "")).lower()
            if op == "routine":
                self.emit_routine(node)
                self.emit_line()
            elif op in {"const", "impl"}:
                continue
            else:
                self.emit_line(f"// top-level Plan42 op {self.safe_comment(op)} preserved; Rust scaffold does not execute it yet")
                self.diagnostics.warn(f"Rust scaffold preserved top-level op as comment: {op}")
        self.emit_rust_main()
        return "\n".join(self.lines).rstrip() + "\n"

    def safe_comment(self, text: Any) -> str:
        return str(text).replace("/*", "/ *").replace("*/", "* /").replace("\n", " ")

    def rust_name(self, value: Any, fallback: str = "p42_value") -> str:
        s = str(value if value is not None and value != "" else fallback)
        s = re.sub(r"[^0-9A-Za-z_]", "_", s)
        if not s or set(s) == {"_"}:
            s = fallback
        if s[0].isdigit():
            s = "_" + s
        if s in self.RUST_KEYWORDS:
            s += "_"
        return s

    def rust_func_name(self, value: Any) -> str:
        name = self.rust_name(value, "routine")
        if name == "main":
            return "p42_user_main"
        return name

    def rust_string(self, value: Any) -> str:
        return json.dumps(str(value), ensure_ascii=False)

    def rust_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t == "int":
            return "i64"
        if t == "float":
            return "f64"
        if t == "bool":
            return "bool"
        if t == "list":
            return "Vec<String>"
        if t == "dict":
            return "std::collections::BTreeMap<String, String>"
        if t == "str":
            return "String"
        return "String"

    def default_expr_for_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t == "int":
            return "0"
        if t == "float":
            return "0.0"
        if t == "bool":
            return "false"
        if t == "list":
            return "Vec::<String>::new()"
        if t == "dict":
            return "std::collections::BTreeMap::<String, String>::new()"
        return "String::new()"

    def infer_type(self, value: Any) -> str:
        if isinstance(value, dict):
            op = str(value.get("op", "")).lower()
            if op == "literal":
                declared = canonical_type_name(value.get("type"))
                if declared:
                    return declared
                v = value.get("value")
                if isinstance(v, bool):
                    return "bool"
                if isinstance(v, int):
                    return "int"
                if isinstance(v, float):
                    return "float"
                if isinstance(v, list):
                    return "list"
                if isinstance(v, dict):
                    return "dict"
                return "str"
            if op == "var":
                return self.var_types.get(str(value.get("name")), canonical_type_name(value.get("type")) or "str")
            if op in {"add", "sub", "mul", "div", "mod", "len"}:
                return "int"
            if op in {"eq", "neq", "lt", "lte", "gt", "gte", "and", "or", "not", "in"}:
                return "bool"
            if op in {"concat", "format", "index", "slice", "call"}:
                return canonical_type_name(value.get("type")) or "str"
            if op == "cast":
                return canonical_type_name(value.get("to")) or self.infer_type(value.get("expr"))
            if op in {"list", "tuple", "set", "range"}:
                return "list"
            return canonical_type_name(value.get("type")) or "str"
        if isinstance(value, bool):
            return "bool"
        if isinstance(value, int):
            return "int"
        if isinstance(value, float):
            return "float"
        if isinstance(value, list):
            return "list"
        if isinstance(value, dict):
            return "dict"
        return "str"

    def _emit_embedded_spec_comments(self) -> None:
        try:
            import base64, gzip
            payload = json.dumps(self.program.spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            encoded = base64.b64encode(gzip.compress(payload, mtime=0)).decode("ascii")
            self.emit_line("// PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN")
            for i in range(0, len(encoded), 72):
                self.emit_line("// " + encoded[i:i+72])
            self.emit_line("// PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END")
            self.emit_line()
        except Exception as exc:
            self.diagnostics.warn(f"failed to embed Plan42 spec in Rust output: {exc}")

    def emit_const(self, node: dict[str, Any]) -> None:
        name = self.rust_name(node.get("name", "CONST")).upper()
        value = node.get("value", {"op": "literal", "value": ""})
        typ = canonical_type_name(node.get("type")) or self.infer_type(value)
        self.var_types[str(node.get("name", name))] = typ
        if typ == "str":
            raw = value.get("value") if isinstance(value, dict) and str(value.get("op", "")).lower() == "literal" else value
            self.emit_line(f"const {name}: &str = {self.rust_string(raw)};")
        elif typ in {"int", "float", "bool"}:
            self.emit_line(f"const {name}: {self.rust_type(typ)} = {self.expr(value)};")
        else:
            self.emit_line(f"// const {name} with Plan42 type {typ} is preserved; Rust scaffold only emits scalar consts")
            self.diagnostics.warn(f"Rust scaffold preserved non-scalar const as comment: {name}")

    def routine_return_type(self, node: dict[str, Any]) -> str:
        declared = canonical_type_name(node.get("return_type"))
        if declared:
            return declared
        for child in node.get("body", []) or []:
            if isinstance(child, dict) and str(child.get("op", "")).lower() == "return":
                return self.infer_type(child.get("expr", child.get("value")))
        return "unit"

    def emit_routine(self, node: dict[str, Any]) -> None:
        name = self.rust_func_name(node.get("name", "routine"))
        params = node.get("params") if isinstance(node.get("params"), list) else []
        ptypes = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
        rendered = []
        for p in params:
            typ = canonical_type_name(ptypes.get(str(p))) or self.var_types.get(str(p), "str")
            self.var_types[str(p)] = typ
            rendered.append(f"{self.rust_name(p)}: {self.rust_type(typ)}")
        ret = self.routine_return_type(node)
        suffix = "" if ret == "unit" else f" -> {self.rust_type(ret)}"
        body = node.get("body", []) or []
        self.emit_line(f"fn {name}({', '.join(rendered)}){suffix} {{")
        self.indent += 1
        self.emit_block(body)
        last_returns = bool(body) and isinstance(body[-1], dict) and str(body[-1].get("op", "")).lower() == "return"
        if ret != "unit" and not last_returns:
            self.emit_line(self.default_expr_for_type(ret))
        self.indent -= 1
        self.emit_line("}")

    def emit_rust_main(self) -> None:
        main_node = next((n for n in self.program.nodes if isinstance(n, dict) and str(n.get("op", "")).lower() == "routine" and str(n.get("name", "")) == "main"), None)
        self.emit_line("fn main() {")
        self.indent += 1
        if main_node is None:
            self.emit_line('// no Plan42 routine named "main" was present')
        else:
            self.emit_line("let mut _p42_args = std::env::args().skip(1);")
            args = []
            params = main_node.get("params") if isinstance(main_node.get("params"), list) else []
            ptypes = main_node.get("param_types") if isinstance(main_node.get("param_types"), dict) else {}
            for i, p in enumerate(params):
                name = f"_p42_arg_{i}"
                typ = canonical_type_name(ptypes.get(str(p))) or self.var_types.get(str(p), "str")
                if typ == "int":
                    self.emit_line(f"let {name}: i64 = _p42_args.next().unwrap_or_else(|| \"0\".to_string()).parse::<i64>().unwrap_or(0);")
                elif typ == "float":
                    self.emit_line(f"let {name}: f64 = _p42_args.next().unwrap_or_else(|| \"0\".to_string()).parse::<f64>().unwrap_or(0.0);")
                elif typ == "bool":
                    self.emit_line(f"let {name}: bool = matches!(_p42_args.next().unwrap_or_else(|| \"false\".to_string()).as_str(), \"1\" | \"true\" | \"TRUE\" | \"yes\" | \"YES\");")
                else:
                    self.emit_line(f"let {name}: String = _p42_args.next().unwrap_or_else(|| \"world\".to_string());")
                args.append(name)
            call = f"p42_user_main({', '.join(args)})"
            if self.routine_return_type(main_node) == "unit":
                self.emit_line(call + ";")
            else:
                self.emit_line("let _p42_status = " + call + ";")
        self.indent -= 1
        self.emit_line("}")

    def emit_block(self, nodes: list[dict[str, Any]]) -> None:
        if not nodes:
            self.emit_line("// pass")
            return
        before = len(self.lines)
        for node in nodes:
            self.emit_node(node)
        if len(self.lines) == before:
            self.emit_line("// pass")

    def node_body(self, node: dict[str, Any], *names: str) -> list[dict[str, Any]]:
        for name in names:
            value = node.get(name)
            if isinstance(value, list):
                return value
        return []

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        if op in {"noop", "pass"}:
            self.emit_line("// pass")
        elif op == "declare":
            name = self.rust_name(node.get("name", "value"))
            typ = canonical_type_name(node.get("type")) or self.infer_type(node.get("value", node.get("expr")))
            self.var_types[str(node.get("name", name))] = typ
            value = node.get("value", node.get("expr", {"op": "literal", "value": None}))
            self.emit_line(f"let mut {name}: {self.rust_type(typ)} = {self.expr(value)};")
        elif op == "assign":
            name = self.rust_name(node.get("name", "value"))
            value = node.get("value", node.get("expr", {"op": "literal", "value": None}))
            self.emit_line(f"{name} = {self.expr(value)};")
        elif op == "output":
            value = node.get("expr", node.get("value", {"op": "literal", "value": ""}))
            self.emit_line(f"println!(\"{{}}\", {self.expr(value)});")
        elif op == "return":
            value = node.get("expr", node.get("value", {"op": "literal", "value": None}))
            self.emit_line(f"return {self.expr(value)};")
        elif op == "if":
            self.emit_if(node)
        elif op == "while":
            self.emit_line(f"while {self.expr(node.get('cond', {'op': 'literal', 'value': False}))} {{")
            self.indent += 1
            self.emit_block(self.node_body(node, "body", "then"))
            self.indent -= 1
            self.emit_line("}")
        elif op == "for_range":
            self.emit_for_range(node)
        elif op == "for_each":
            self.emit_for_each(node)
        elif op == "break":
            self.emit_line("break;")
        elif op == "continue":
            self.emit_line("continue;")
        elif op == "assert":
            self.emit_line(f"assert!({self.expr(node.get('cond', node.get('expr', {'op':'literal', 'value': True})))});")
        elif op == "raise":
            msg = node.get("message", node.get("expr", {"op": "literal", "value": "Plan42 raise"}))
            self.emit_line(f"panic!(\"{{}}\", {self.expr(msg)});")
        elif op == "impl_use":
            self.emit_line(f"// unresolved impl_use {self.safe_comment(node.get('name', ''))}; Rust scaffold did not execute it")
            self.diagnostics.unresolved_impls.append(str(node.get("name", "")))
        else:
            self.emit_line(f"// unsupported Plan42 op {self.safe_comment(op)} preserved by Rust scaffold")
            self.diagnostics.warn(f"Rust scaffold preserved unsupported op: {op}")

    def emit_if(self, node: dict[str, Any]) -> None:
        cond = self.expr(node.get("cond", {"op": "literal", "value": False}))
        self.emit_line(f"if {cond} {{")
        self.indent += 1
        self.emit_block(self.node_body(node, "body", "then"))
        self.indent -= 1
        else_body = self.node_body(node, "else_body", "else")
        if else_body:
            self.emit_line("} else {")
            self.indent += 1
            self.emit_block(else_body)
            self.indent -= 1
        self.emit_line("}")

    def emit_for_range(self, node: dict[str, Any]) -> None:
        var = self.rust_name(node.get("var", "i"))
        start = self.expr(node.get("from", node.get("start", {"op": "literal", "value": 0, "type": "int"})))
        end = self.expr(node.get("to", node.get("end", {"op": "literal", "value": 0, "type": "int"})))
        step_node = node.get("step", {"op": "literal", "value": 1, "type": "int"})
        step = 1
        if isinstance(step_node, dict) and str(step_node.get("op", "")).lower() == "literal":
            try:
                step = int(step_node.get("value", 1))
            except Exception:
                step = 1
        range_expr = f"{start}..{end}"
        if step > 1:
            range_expr = f"({range_expr}).step_by({step})"
        self.emit_line(f"for {var} in {range_expr} {{")
        self.indent += 1
        self.var_types[str(node.get("var", var))] = "int"
        self.emit_block(self.node_body(node, "body"))
        self.indent -= 1
        self.emit_line("}")

    def emit_for_each(self, node: dict[str, Any]) -> None:
        var = self.rust_name(node.get("var", "item"))
        coll = self.expr(node.get("in", node.get("collection", {"op": "list", "items": []})))
        self.emit_line(f"for {var} in {coll} {{")
        self.indent += 1
        self.var_types[str(node.get("var", var))] = "str"
        self.emit_block(self.node_body(node, "body"))
        self.indent -= 1
        self.emit_line("}")

    def expr(self, value: Any) -> str:
        if not isinstance(value, dict):
            if value is None:
                return "String::new()"
            if isinstance(value, bool):
                return "true" if value else "false"
            if isinstance(value, int) or isinstance(value, float):
                return repr(value)
            if isinstance(value, list):
                return "vec![" + ", ".join(self.expr({"op": "literal", "value": x}) for x in value) + "]"
            return f"String::from({self.rust_string(value)})"
        op = str(value.get("op", "")).lower()
        if op == "literal":
            v = value.get("value")
            typ = canonical_type_name(value.get("type")) or self.infer_type(value)
            if v is None:
                return self.default_expr_for_type(typ)
            if typ == "bool" or isinstance(v, bool):
                return "true" if bool(v) else "false"
            if typ in {"int", "float"} or isinstance(v, (int, float)):
                return repr(v)
            if typ == "list" or isinstance(v, list):
                return "vec![" + ", ".join(self.expr({"op": "literal", "value": x, "type": "str"}) for x in (v or [])) + "]"
            return f"String::from({self.rust_string(v)})"
        if op == "nil":
            return "String::new()"
        if op == "var":
            return self.rust_name(value.get("name", "value"))
        if op == "cast":
            inner = self.expr(value.get("expr", value.get("value")))
            to = canonical_type_name(value.get("to"))
            if to == "str":
                return f"({inner}).to_string()"
            if to == "int":
                return f"({inner}).to_string().parse::<i64>().unwrap_or(0)"
            if to == "float":
                return f"({inner}).to_string().parse::<f64>().unwrap_or(0.0)"
            if to == "bool":
                return f"!({inner}).to_string().is_empty()"
            return inner
        if op in self.BINOPS:
            left = self.expr(value.get("left"))
            right = self.expr(value.get("right"))
            return f"({left} {self.BINOPS[op]} {right})"
        if op == "not":
            return f"!({self.expr(value.get('expr', value.get('value')) )})"
        if op == "concat":
            parts = value.get("args", value.get("parts"))
            if not isinstance(parts, list):
                parts = [value.get("left"), value.get("right")]
            fmt = "{}" * len([p for p in parts if p is not None])
            args = ", ".join(self.expr(p) for p in parts if p is not None)
            return f"format!({self.rust_string(fmt)}{', ' if args else ''}{args})"
        if op == "format":
            template = str(value.get("template", ""))
            args_obj = value.get("args") if isinstance(value.get("args"), dict) else {}
            ordered: list[str] = []
            def repl(match: re.Match[str]) -> str:
                key = match.group(1)
                if key in args_obj:
                    ordered.append(self.expr(args_obj[key]))
                    return "{}"
                return match.group(0).replace("{", "{{").replace("}", "}}")
            rendered_template = re.sub(r"\{([A-Za-z_][A-Za-z0-9_]*)\}", repl, template)
            rendered_template = rendered_template.replace("\n", "\\n")
            return f"format!({self.rust_string(rendered_template)}{', ' if ordered else ''}{', '.join(ordered)})"
        if op == "call":
            name = self.rust_func_name(value.get("routine", value.get("name", "call")))
            args = ", ".join(self.expr(x) for x in (value.get("args") or []))
            return f"{name}({args})"
        if op == "len":
            inner = self.expr(value.get("expr", value.get("value")))
            return f"({inner}).len() as i64"
        if op == "in":
            item = self.expr(value.get("item", value.get("left")))
            coll = self.expr(value.get("collection", value.get("right")))
            return f"({coll}).contains(&{item})"
        if op == "index":
            coll = self.expr(value.get("collection", value.get("obj")))
            idx = self.expr(value.get("key", value.get("index")))
            return f"({coll})[{idx} as usize].clone()"
        if op == "ternary":
            cond = self.expr(value.get("cond"))
            yes = self.expr(value.get("then", value.get("if_true")))
            no = self.expr(value.get("else", value.get("if_false")))
            return f"if {cond} {{ {yes} }} else {{ {no} }}"
        if op in {"list", "tuple", "set"}:
            items = value.get("items", value.get("values", value.get("args", [])))
            if not isinstance(items, list):
                items = []
            return "vec![" + ", ".join(self.expr(x) for x in items) + "]"
        if op == "impl_use":
            name = str(value.get("name", ""))
            self.diagnostics.unresolved_impls.append(name)
            return f"/* unresolved impl_use {self.safe_comment(name)} */ {self.default_expr_for_type(value.get('type'))}"
        if op in {"method", "new", "attribute"}:
            self.diagnostics.warn(f"Rust scaffold preserved object expression without native semantics: {op}")
            return self.default_expr_for_type(value.get("type"))
        self.diagnostics.warn(f"unsupported Rust expression op emitted as default: {op}")
        return self.default_expr_for_type(value.get("type"))


class OORexxBackend(UnsupportedBackend):
    language = "oorexx"
    file_extension = ".cls"


class ClassicRexxBackend(Backend):
    """Conservative Plan42 -> Classic Rexx backend for Regina.

    This target deliberately sticks to portable classic Rexx constructs: SAY,
    PARSE ARG, PROCEDURE, DO/END, LEAVE, ITERATE, RETURN, WORDS/WORD, and simple
    expression syntax.  It is intended as the first Regina-friendly backend, not
    an ooRexx object emitter.
    """

    language = "regina"
    file_extension = ".rexx"

    BINOPS = {
        "add": "+", "sub": "-", "mul": "*", "div": "/", "mod": "//",
        "eq": "=", "neq": "\\=", "lt": "<", "lte": "<=", "gt": ">", "gte": ">=",
    }

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        super().__init__(program, include_runtime=include_runtime)
        self.loop_counter = 0
        self.label_counter = 0
        self.lambda_counter = 0
        self.impl_helper_names: dict[str, str] = {}

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        self._emit_header()
        self._emit_embedded_spec_comments()
        self._emit_top_level()
        self._emit_impl_helpers()
        self._emit_routines()
        return "\n".join(self.lines).rstrip() + "\n"

    def _emit_header(self) -> None:
        module = str(self.program.spec.get("module", "Plan42Module"))
        self.emit_line("/* Generated from Plan42 by plan42c.py: Classic Rexx / Regina target */")
        self.emit_line(f"/* Module: {module} */")
        desc = str(self.program.spec.get("description", "")).strip()
        if desc:
            for line in desc.splitlines():
                self.emit_line("/* " + line.replace("*/", "* /") + " */")
        self.emit_line("signal on syntax name p42_syntax")
        self.emit_line()

    def _emit_embedded_spec_comments(self) -> None:
        try:
            import base64, gzip
            payload = json.dumps(self.program.spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            encoded = base64.b64encode(gzip.compress(payload, mtime=0)).decode("ascii")
            self.emit_line("/* PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN")
            for i in range(0, len(encoded), 76):
                self.emit_line("   " + encoded[i:i+76])
            self.emit_line("   PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END */")
            self.emit_line()
        except Exception as exc:
            self.diagnostics.warn(f"failed to embed Plan42 spec in Rexx output: {exc}")

    def _emit_top_level(self) -> None:
        main_node = None
        emitted_top = False
        for node in self.program.nodes:
            op = str(node.get("op", "")).lower()
            if op in {"impl", "routine", "class", "method"}:
                if op == "routine" and node.get("name") == "main":
                    main_node = node
                continue
            self.emit_node(node)
            emitted_top = True
        if main_node is not None:
            params = [self.rexx_name(p) for p in (main_node.get("params") or [])]
            if params:
                self.emit_line("parse arg " + " ".join("__p42_arg_" + str(i+1) for i in range(len(params))))
                args = ", ".join("__p42_arg_" + str(i+1) for i in range(len(params)))
                self.emit_line(f"call {self.rexx_name('main')} {args}")
            else:
                self.emit_line(f"call {self.rexx_name('main')}")
            emitted_top = True
        if emitted_top:
            self.emit_line("exit 0")
            self.emit_line()
        self.emit_line("p42_syntax:")
        self.indent += 1
        self.emit_line("say 'Plan42 Regina runtime error:' rc 'at line' sigl")
        self.emit_line("exit rc")
        self.indent -= 1
        self.emit_line()
        self._emit_runtime_helpers()

    def _next_label(self, prefix: str) -> str:
        self.label_counter += 1
        return self.rexx_name(prefix + '_' + str(self.label_counter))

    def _block_ends_with_return(self, nodes: list[dict[str, Any]]) -> bool:
        if not nodes:
            return False
        last = nodes[-1]
        if not isinstance(last, dict):
            return False
        op = str(last.get("op", "")).lower()
        if op == "return":
            return True
        # Conservative: only avoid fallback for an if when both branches end in RETURN.
        if op == "if":
            then_nodes = node_list(last.get("then")) or node_list(last.get("body"))
            else_nodes = node_list(last.get("else")) or node_list(last.get("else_body"))
            return self._block_ends_with_return(then_nodes) and self._block_ends_with_return(else_nodes)
        return False

    def _emit_runtime_helpers(self) -> None:
        self.emit_line("p42_unresolved_impl:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg name")
        self.emit_line("say 'Plan42 unresolved Regina implementation:' name")
        self.emit_line("exit 99")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_raise:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg typ, msg")
        self.emit_line("say 'Plan42 Regina raised:' typ msg")
        self.emit_line("exit 98")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_index:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg obj, idx")
        self.emit_line("if datatype(idx, 'W') then return word(obj, idx + 1)")
        self.emit_line("do __i = 1 to words(obj)")
        self.indent += 1
        self.emit_line("__pair = word(obj, __i)")
        self.emit_line("parse var __pair __k '=' __v")
        self.emit_line("if __k = idx then return __v")
        self.indent -= 1
        self.emit_line("end")
        self.emit_line("return ''")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_in:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg item, coll")
        self.emit_line("if wordpos(item, coll) > 0 then return 1")
        self.emit_line("do __i = 1 to words(coll)")
        self.indent += 1
        self.emit_line("__pair = word(coll, __i)")
        self.emit_line("parse var __pair __k '=' __v")
        self.emit_line("if __k = item then return 1")
        self.indent -= 1
        self.emit_line("end")
        self.emit_line("return 0")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_slice:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg obj, first, last")
        self.emit_line("first = first + 1")
        self.emit_line("if last = '' then last = words(obj)")
        self.emit_line("count = last - first + 1")
        self.emit_line("if count < 0 then count = 0")
        self.emit_line("return subword(obj, first, count)")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_ternary:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg cond, thenv, elsev")
        self.emit_line("if cond then return thenv")
        self.emit_line("return elsev")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_format:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg template, pairs")
        self.emit_line("out = template")
        self.emit_line("do __i = 1 to words(pairs)")
        self.indent += 1
        self.emit_line("__pair = word(pairs, __i)")
        self.emit_line("parse var __pair __k '=' __v")
        self.emit_line("out = changestr('{' || __k || '}', out, __v)")
        self.indent -= 1
        self.emit_line("end")
        self.emit_line("return out")
        self.indent -= 1
        self.emit_line()
        self.emit_line("p42_method:")
        self.indent += 1
        self.emit_line("procedure")
        self.emit_line("parse arg obj, method, a1, a2")
        self.emit_line("select")
        self.indent += 1
        self.emit_line("when method = 'get' then return p42_index(obj, a1)")
        self.emit_line("when method = 'strip' then return strip(obj)")
        self.emit_line("when method = 'upper' then return translate(obj)")
        self.emit_line("when method = 'lower' then return translate(obj, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')")
        self.emit_line("when method = 'words' then return words(obj)")
        self.emit_line("when method = 'word' then return word(obj, a1)")
        self.emit_line("otherwise do")
        self.indent += 1
        self.emit_line("say 'Plan42 unsupported Regina method:' method")
        self.emit_line("exit 97")
        self.indent -= 1
        self.emit_line("end")
        self.indent -= 1
        self.emit_line("end")
        self.indent -= 1
        self.emit_line()

    def _emit_impl_helpers(self) -> None:
        for name in sorted(self.program.impls):
            impl_def = self.program.impls[name]
            helper = self.impl_helper_name(name)
            self.impl_helper_names[name] = helper
            impl = impl_def.implementation_for("regina")
            self.emit_line(f"{helper}:")
            self.indent += 1
            self.emit_line(self.procedure_line())
            if impl_def.params:
                self.emit_line("parse arg " + ", ".join(self.rexx_name(p) for p in impl_def.params))
            if impl_def.abstract:
                self.emit_line("/* " + impl_def.abstract.replace("*/", "* /") + " */")
            if impl is None:
                self.emit_line("return p42_unresolved_impl(" + self._quote_text(name) + ")")
                self.diagnostics.unresolved_impls.append(name)
            else:
                self._emit_impl_body(impl_def, impl)
            self.indent -= 1
            self.emit_line()
            self.diagnostics.emitted_impl_helpers += 1

    def _emit_impl_body(self, impl_def: ImplDefinition, impl: dict[str, Any]) -> None:
        impl_type = str(impl.get("type", "inline")).lower()
        if impl_type in {"inline", "library", "command"}:
            body = impl.get("body")
            inline = impl.get("inline")
            if isinstance(body, list):
                body_nodes = node_list(body)
                self.emit_block(body_nodes)
                if not self._block_ends_with_return(body_nodes):
                    self.emit_line("return ''")
                return
            if isinstance(inline, str) and inline.strip():
                for line in inline.strip("\n").splitlines():
                    self.emit_line(line.rstrip())
                if not inline.strip().lower().startswith("return") and "\nreturn" not in inline.lower():
                    self.emit_line("return ''")
                return
        self.emit_line("return ''")

    def _emit_routines(self) -> None:
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "routine":
                self.emit_routine(node)
                self.emit_line()

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        self.diagnostics.emitted_nodes += 1
        if op == "const":
            self.emit_line(f"{self.rexx_name(node.get('name'))} = {self.rexx_literal(node.get('value'))}")
        elif op == "declare":
            name = self.rexx_name(node.get("name", "p42_value"))
            value_node = node.get("value", node.get("expr"))
            rendered = self.default_for_type(node.get("type")) if value_node is None else self.expr(value_node)
            self.emit_line(f"{name} = {rendered}")
        elif op == "assign":
            target = self.rexx_name(node.get("target", node.get("name", "p42_value")))
            self.emit_line(f"{target} = {self.expr(node.get('expr', node.get('value')))}")
        elif op == "routine":
            self.emit_routine(node)
        elif op == "return":
            val = node.get("expr", node.get("value"))
            self.emit_line("return" if val is None else "return " + self.expr(val))
        elif op == "output":
            self.emit_line("say " + self.expr(node.get("expr", node.get("value"))))
        elif op == "if":
            self.emit_if(node)
        elif op == "while":
            self.emit_line("do while " + self.expr(node.get("cond")))
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("end")
        elif op == "until":
            self.emit_line("do until " + self.expr(node.get("cond")))
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("end")
        elif op == "for_each":
            self.loop_counter += 1
            var = self.rexx_name(node.get("var", node.get("item", "item")))
            seq = "__p42_words_" + str(self.loop_counter)
            idx = "__p42_i_" + str(self.loop_counter)
            self.emit_line(f"{seq} = {self.expr(node.get('iter_expr', node.get('in', {'op':'literal','value':[]})))}")
            self.emit_line(f"do {idx} = 1 to words({seq})")
            self.indent += 1
            self.emit_line(f"{var} = word({seq}, {idx})")
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("end")
        elif op == "for_range":
            var = self.rexx_name(node.get("var", "i"))
            start = self.expr(node.get("from", {"op":"literal","value":0}))
            stop = self.expr(node.get("to", node.get("stop", {"op":"literal","value":0})))
            step = self.expr(node.get("step", {"op":"literal","value":1}))
            self.emit_line(f"do {var} = {start} to ({stop}) - 1 by {step}")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("end")
        elif op == "try":
            self.emit_try(node)
        elif op == "raise":
            typ = self.expr(node.get("type", {"op":"literal","value":"Error"}))
            msg = self.expr(node.get("message", {"op":"literal","value":""}))
            self.emit_line(f"call p42_raise {typ}, {msg}")
        elif op == "match":
            self.emit_match(node)
        elif op == "struct":
            self.emit_line("/* Plan42 struct/record declaration: " + self.rexx_name(node.get("name", "Record")) + " */")
        elif op == "break":
            self.emit_line("leave")
        elif op == "continue":
            self.emit_line("iterate")
        elif op == "impl_use":
            call = self.impl_call_expr(node)
            result = node.get("result")
            if result:
                self.emit_line(f"{self.rexx_name(result)} = {call}")
            else:
                self.emit_line(f"call {call}")
        elif op == "module":
            self.emit_block(node_list(node.get("body")))
        else:
            self.emit_line(f"/* unsupported Plan42 op preserved as no-op: {op} */")
            self.diagnostics.warn(f"Regina target preserved unsupported op as no-op: {op}")

    def emit_block(self, nodes: list[dict[str, Any]]) -> None:
        if not nodes:
            self.emit_line("nop")
            return
        before = len(self.lines)
        for node in nodes:
            self.emit_node(node)
        if len(self.lines) == before:
            self.emit_line("nop")

    def emit_routine(self, node: dict[str, Any]) -> None:
        name = self.rexx_name(node.get("name", "routine"))
        self.emit_line(f"{name}:")
        self.indent += 1
        self.emit_line(self.procedure_line())
        params = [self.rexx_name(p) for p in (node.get("params") or [])]
        if params:
            self.emit_line("parse arg " + ", ".join(params))
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line("/* " + purpose.replace("*/", "* /") + " */")
        body_nodes = node_list(node.get("body"))
        self.emit_block(body_nodes)
        if not self._block_ends_with_return(body_nodes):
            self.emit_line("return ''")
        self.indent -= 1

    def emit_try(self, node: dict[str, Any]) -> None:
        catch_label = self._next_label("p42_try_catch")
        finally_label = self._next_label("p42_try_finally")
        end_label = self._next_label("p42_try_end")
        catches = node.get("catches") if isinstance(node.get("catches"), list) else []
        finally_body = node_list(node.get("finally"))
        self.emit_line("signal on syntax name " + catch_label)
        self.emit_block(node_list(node.get("body")))
        self.emit_line("signal off syntax")
        if finally_body:
            self.emit_line("signal " + finally_label)
        else:
            self.emit_line("signal " + end_label)
        self.emit_line(catch_label + ":")
        self.indent += 1
        self.emit_line("signal off syntax")
        if catches:
            catch = catches[0]
            var = self.rexx_name(catch.get("var", "p42_exception"))
            self.emit_line(var + " = condition('O')")
            self.emit_block(node_list(catch.get("body")))
        else:
            self.emit_line("say 'Plan42 Regina uncaught condition:' condition('O')")
            self.emit_line("exit 96")
        if finally_body:
            self.emit_line("signal " + finally_label)
        else:
            self.emit_line("signal " + end_label)
        self.indent -= 1
        if finally_body:
            self.emit_line(finally_label + ":")
            self.indent += 1
            self.emit_block(finally_body)
            self.emit_line("signal " + end_label)
            self.indent -= 1
        self.emit_line(end_label + ":")
        self.indent += 1
        self.emit_line("nop")
        self.indent -= 1

    def emit_match(self, node: dict[str, Any]) -> None:
        expr = self.expr(node.get("expr"))
        self.emit_line("select")
        self.indent += 1
        default_body: list[dict[str, Any]] = []
        for arm in node.get("arms", []) if isinstance(node.get("arms"), list) else []:
            pat = arm.get("pattern")
            body = node_list(arm.get("body"))
            if pat is None:
                default_body = body
                continue
            pat_expr = self.expr(pat if isinstance(pat, dict) else {"op":"literal","value":pat})
            self.emit_line("when " + expr + " = " + pat_expr + " then do")
            self.indent += 1
            self.emit_block(body)
            self.indent -= 1
            self.emit_line("end")
        self.emit_line("otherwise do")
        self.indent += 1
        self.emit_block(default_body)
        self.indent -= 1
        self.emit_line("end")
        self.indent -= 1
        self.emit_line("end")

    def emit_if(self, node: dict[str, Any]) -> None:
        self.emit_line("if " + self.expr(node.get("cond")) + " then do")
        self.indent += 1
        self.emit_block(node_list(node.get("then")) or node_list(node.get("body")))
        self.indent -= 1
        elifs = node.get("elif") if isinstance(node.get("elif"), list) else []
        for arm in elifs:
            self.emit_line("end")
            self.emit_line("else if " + self.expr(arm.get("cond")) + " then do")
            self.indent += 1
            self.emit_block(node_list(arm.get("body")))
            self.indent -= 1
        else_body = node_list(node.get("else")) or node_list(node.get("else_body"))
        if else_body:
            self.emit_line("end")
            self.emit_line("else do")
            self.indent += 1
            self.emit_block(else_body)
            self.indent -= 1
        self.emit_line("end")

    def expr(self, value: Any) -> str:
        if value is None:
            return "''"
        if isinstance(value, str):
            return self.rexx_name(value)
        if not isinstance(value, dict):
            return self.rexx_literal(value)
        op = str(value.get("op", "")).lower()
        if op == "literal":
            return self.rexx_literal(value.get("value"))
        if op == "var":
            return self.rexx_name(value.get("name", "p42_value"))
        if op == "cast":
            inner = self.expr(value.get("expr"))
            to = canonical_type_name(value.get("to"))
            if to == "str":
                return "('' || " + inner + ")"
            if to in {"int", "float"}:
                return "(" + inner + " + 0)"
            if to == "bool":
                return "(" + inner + " \\= 0 & " + inner + " \\= '')"
            return inner
        if op == "nil":
            return "''"
        if op in {"add", "sub", "mul", "div", "mod", "eq", "neq", "lt", "lte", "gt", "gte"}:
            return "(" + self.expr(value.get("left")) + " " + self.BINOPS[op] + " " + self.expr(value.get("right")) + ")"
        if op == "and":
            return "(" + self.expr(value.get("left")) + " & " + self.expr(value.get("right")) + ")"
        if op == "or":
            return "(" + self.expr(value.get("left")) + " | " + self.expr(value.get("right")) + ")"
        if op == "not":
            inner = value.get("value", value.get("expr"))
            return "(\\ " + self.expr(inner) + ")"
        if op == "concat":
            if isinstance(value.get("args"), list):
                parts = [self.expr(x) for x in value.get("args", [])]
            elif isinstance(value.get("parts"), list):
                parts = [self.expr(x) for x in value.get("parts", [])]
            else:
                parts = [self.expr(value.get("left")), self.expr(value.get("right"))]
            return " || ".join(parts) or "''"
        if op == "call":
            routine = self.rexx_name(value.get("routine", value.get("name", "call")))
            args = ", ".join(self.expr(x) for x in (value.get("args") or []))
            return f"{routine}({args})"
        if op == "impl_use":
            return self.impl_call_expr(value)
        if op == "format":
            template = self.expr({"op":"literal", "value": value.get("template", ""), "type":"str"})
            args = value.get("args") if isinstance(value.get("args"), dict) else {}
            pairs = []
            for k, v in args.items():
                pairs.append(str(k) + "=" + "' || " + self.expr(v) + " || '")
            pair_text = self._quote_text(" ".join(pairs)) if pairs else "''"
            return f"p42_format({template}, {pair_text})"
        if op == "in":
            return "p42_in(" + self.expr(value.get("item")) + ", " + self.expr(value.get("collection")) + ")"
        if op == "index":
            return "p42_index(" + self.expr(value.get("obj")) + ", " + self.expr(value.get("index")) + ")"
        if op == "slice":
            return "p42_slice(" + self.expr(value.get("obj")) + ", " + self.expr(value.get("from", {"op":"literal","value":0})) + ", " + self.expr(value.get("to", {"op":"literal","value":""})) + ")"
        if op == "ternary":
            return "p42_ternary(" + self.expr(value.get("cond")) + ", " + self.expr(value.get("then")) + ", " + self.expr(value.get("else")) + ")"
        if op == "method":
            obj = self.expr(value.get("obj"))
            name = self.expr({"op":"literal", "value": value.get("name", ""), "type":"str"})
            args = [self.expr(x) for x in (value.get("args") or [])]
            while len(args) < 2:
                args.append("''")
            return "p42_method(" + ", ".join([obj, name] + args[:2]) + ")"
        if op == "lambda":
            self.lambda_counter += 1
            label = self.rexx_name("p42_lambda_" + str(self.lambda_counter))
            self.diagnostics.warn("Regina backend emitted lambda as named placeholder " + label)
            return self._quote_text(label)
        self.diagnostics.warn(f"unsupported Regina expression op emitted as loud failure: {op}")
        return f"p42_unresolved_impl({self._quote_text('expr:' + op)})"

    def impl_call_expr(self, node: dict[str, Any]) -> str:
        name = str(node.get("name", ""))
        args = ", ".join(self.expr(x) for x in (node.get("args") or []))
        if name in self.program.impls:
            return f"{self.impl_helper_name(name)}({args})"
        if name in self.program.routines:
            return f"{self.rexx_name(name)}({args})"
        self.diagnostics.unresolved_impls.append(name)
        return f"p42_unresolved_impl({self._quote_text(name)}{', ' + args if args else ''})"

    def impl_helper_name(self, name: str) -> str:
        return self.rexx_name("p42_impl_" + name)

    def default_for_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t in {"int", "float"}:
            return "0"
        if t == "bool":
            return "0"
        return "''"

    def procedure_line(self) -> str:
        consts = [self.rexx_name(c) for c in sorted(self.program.constants)]
        if consts:
            return "procedure expose " + " ".join(consts)
        return "procedure"

    def rexx_literal(self, value: Any) -> str:
        if isinstance(value, dict):
            if "op" in value:
                return self.expr(value)
            return self._quote_text(" ".join(str(k) + "=" + str(v) for k, v in value.items()))
        if isinstance(value, bool):
            return "1" if value else "0"
        if isinstance(value, (int, float)):
            return str(value)
        if value is None:
            return "''"
        if isinstance(value, (list, tuple, set)):
            return self._quote_text(" ".join(str(x) for x in value))
        return self._quote_text(str(value))

    def _quote_text(self, text: str) -> str:
        return '"' + text.replace('"', '""') + '"'

    def rexx_name(self, value: Any, *, fallback: str = "p42_value") -> str:
        text = str(value if value is not None and value != "" else fallback)
        text = re.sub(r"[^0-9A-Za-z_!?]", "_", text)
        if not text or set(text) == {"_"}:
            text = fallback
        if text[0].isdigit():
            text = "_" + text
        upper = text.upper()
        if upper in {"ARG", "DO", "END", "EXIT", "IF", "THEN", "ELSE", "RETURN", "SAY", "SELECT", "WHEN", "OTHERWISE", "SIGNAL", "CALL", "PROCEDURE", "PARSE", "PULL", "PUSH", "QUEUE", "TRACE", "NUMERIC"}:
            text += "_"
        return text


# ---------------------------------------------------------------------------
# ooRexx backend
# ---------------------------------------------------------------------------


class OORexxBackend(ClassicRexxBackend):
    """Plan42 -> ooRexx backend.

    The ooRexx target uses an ooRexx application shape rather than the Classic
    Rexx label-only shape:

    * executable top-level code first;
    * Plan42 routine named ``main`` is inlined as that top-level code;
    * additional routines are emitted as ``::routine`` directives;
    * classes/methods are emitted as ``::class`` / ``::method`` directives;
    * ``::requires`` directives are emitted last.
    """

    language = "oorexx"
    file_extension = ".rex"

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        super().__init__(program, include_runtime=include_runtime)
        self.requires: list[str] = []

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        self._collect_requires()
        self._emit_header()
        self._emit_embedded_spec_comments()
        self._emit_oorexx_top_level()
        self._emit_oorexx_runtime_routines()
        self._emit_oorexx_impl_routines()
        self._emit_oorexx_routines()
        self._emit_oorexx_classes()
        self._emit_oorexx_requires()
        return "\n".join(self.lines).rstrip() + "\n"

    def _emit_header(self) -> None:
        module = str(self.program.spec.get("module", "Plan42Module"))
        self.emit_line("/* Generated from Plan42 by plan42c.py: ooRexx target */")
        self.emit_line(f"/* Module: {module} */")
        desc = str(self.program.spec.get("description", "")).strip()
        if desc:
            for line in desc.splitlines():
                self.emit_line("/* " + line.replace("*/", "* /") + " */")
        self.emit_line("signal on syntax name p42_syntax")
        self.emit_line()

    def _collect_requires(self) -> None:
        seen: set[str] = set()
        def add_req(value: Any) -> None:
            if value is None:
                return
            text = str(value).strip()
            if text and text not in seen:
                seen.add(text)
                self.requires.append(text)
        spec_requires = self.program.spec.get("requires")
        if isinstance(spec_requires, list):
            for req in spec_requires:
                add_req(req)
        elif spec_requires:
            add_req(spec_requires)
        for node in self.program.nodes:
            op = str(node.get("op", "")).lower() if isinstance(node, dict) else ""
            if op in {"requires", "require"}:
                value = node.get("path", node.get("name", node.get("value")))
                add_req(value)
            node_requires = node.get("requires") if isinstance(node, dict) else None
            if isinstance(node_requires, list):
                for req in node_requires:
                    add_req(req)

    def _emit_oorexx_top_level(self) -> None:
        main_node = None
        emitted_top = False
        for node in self.program.nodes:
            op = str(node.get("op", "")).lower()
            if op in {"impl", "routine", "class", "method", "struct", "requires", "require"}:
                if op == "routine" and node.get("name") == "main":
                    main_node = node
                continue
            self.emit_node(node)
            emitted_top = True
        if main_node is not None:
            params = [self.rexx_name(p) for p in (main_node.get("params") or [])]
            if params:
                self.emit_line("parse arg " + ", ".join(params))
            purpose = str(main_node.get("business_purpose", "")).strip()
            if purpose:
                self.emit_line("/* " + purpose.replace("*/", "* /") + " */")
            self.emit_block(node_list(main_node.get("body")))
            emitted_top = True
        if emitted_top:
            self.emit_line("exit 0")
            self.emit_line()
        self.emit_line("p42_syntax:")
        self.indent += 1
        self.emit_line("say 'Plan42 ooRexx runtime error:' rc 'at line' sigl")
        self.emit_line("say condition('O')")
        self.emit_line("exit rc")
        self.indent -= 1
        self.emit_line()

    def _emit_oorexx_runtime_routines(self) -> None:
        self.emit_line("::routine p42_unresolved_impl")
        self.indent += 1
        self.emit_line("use arg name")
        self.emit_line("say 'Plan42 unresolved ooRexx implementation:' name")
        self.emit_line("exit 99")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_raise")
        self.indent += 1
        self.emit_line("use arg typ, msg")
        self.emit_line("say 'Plan42 ooRexx raised:' typ msg")
        self.emit_line("exit 98")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_index")
        self.indent += 1
        self.emit_line("use arg obj, idx")
        self.emit_line("if obj = .nil then return .nil")
        self.emit_line("if obj~hasMethod('at') then return obj~at(idx)")
        self.emit_line("if datatype(idx, 'W') then return word(obj, idx + 1)")
        self.emit_line("return .nil")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_in")
        self.indent += 1
        self.emit_line("use arg item, coll")
        self.emit_line("if coll = .nil then return 0")
        self.emit_line("if coll~hasMethod('hasIndex') then return coll~hasIndex(item)")
        self.emit_line("if coll~hasMethod('hasItem') then return coll~hasItem(item)")
        self.emit_line("if wordpos(item, coll) > 0 then return 1")
        self.emit_line("return 0")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_slice")
        self.indent += 1
        self.emit_line("use arg obj, first, last")
        self.emit_line("if obj = .nil then return .nil")
        self.emit_line("if last = '' then last = words(obj)")
        self.emit_line("first = first + 1")
        self.emit_line("count = last - first + 1")
        self.emit_line("if count < 0 then count = 0")
        self.emit_line("if obj~hasMethod('section') then return obj~section(first, count)")
        self.emit_line("return subword(obj, first, count)")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_ternary")
        self.indent += 1
        self.emit_line("use arg cond, thenv, elsev")
        self.emit_line("if cond then return thenv")
        self.emit_line("return elsev")
        self.indent -= 1
        self.emit_line()
        self.emit_line("::routine p42_format")
        self.indent += 1
        self.emit_line("use arg template, pairs")
        self.emit_line("out = template")
        self.emit_line("do __i = 1 to words(pairs)")
        self.indent += 1
        self.emit_line("__pair = word(pairs, __i)")
        self.emit_line("parse var __pair __k '=' __v")
        self.emit_line("out = changestr('{' || __k || '}', out, __v)")
        self.indent -= 1
        self.emit_line("end")
        self.emit_line("return out")
        self.indent -= 1
        self.emit_line()

    def _emit_oorexx_impl_routines(self) -> None:
        for name in sorted(self.program.impls):
            impl_def = self.program.impls[name]
            helper = self.impl_helper_name(name)
            self.impl_helper_names[name] = helper
            impl = impl_def.implementation_for("oorexx") or impl_def.implementation_for("rexx") or impl_def.implementation_for("generic")
            self.emit_line(f"::routine {helper}")
            self.indent += 1
            if impl_def.params:
                self.emit_line("use arg " + ", ".join(self.rexx_name(p) for p in impl_def.params))
            if impl_def.abstract:
                self.emit_line("/* " + impl_def.abstract.replace("*/", "* /") + " */")
            if impl is None:
                self.emit_line("return p42_unresolved_impl(" + self._quote_text(name) + ")")
                self.diagnostics.unresolved_impls.append(name)
            else:
                self._emit_impl_body(impl_def, impl)
            self.indent -= 1
            self.emit_line()
            self.diagnostics.emitted_impl_helpers += 1

    def _emit_oorexx_routines(self) -> None:
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "routine" and node.get("name") != "main":
                self.emit_routine(node)
                self.emit_line()

    def _emit_oorexx_classes(self) -> None:
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "class":
                self.emit_class(node)
                self.emit_line()

    def _emit_oorexx_requires(self) -> None:
        if not self.requires:
            return
        for req in self.requires:
            self.emit_line(f"::requires {self._quote_text(req)}")

    def emit_routine(self, node: dict[str, Any]) -> None:
        name = self.rexx_name(node.get("name", "routine"))
        self.emit_line(f"::routine {name}")
        self.indent += 1
        params = [self.rexx_name(p) for p in (node.get("params") or [])]
        if params:
            self.emit_line("use arg " + ", ".join(params))
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line("/* " + purpose.replace("*/", "* /") + " */")
        body_nodes = node_list(node.get("body"))
        self.emit_block(body_nodes)
        if not self._block_ends_with_return(body_nodes):
            self.emit_line("return .nil")
        self.indent -= 1

    def emit_class(self, node: dict[str, Any]) -> None:
        name = self.rexx_name(node.get("name", "GeneratedClass"))
        parents = [self.rexx_name(p) for p in (node.get("parents") or []) if p]
        parent_text = " subclass " + parents[0] if parents else ""
        self.emit_line(f"::class {name}{parent_text}")
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line("/* " + purpose.replace("*/", "* /") + " */")
        methods = node_list(node.get("methods"))
        if not methods:
            self.emit_line("::method p42_noop")
            self.indent += 1
            self.emit_line("return .nil")
            self.indent -= 1
            return
        for method in methods:
            self.emit_method(method)

    def emit_method(self, node: dict[str, Any]) -> None:
        name = self.rexx_name(node.get("name", "method"))
        params = [self.rexx_name(p) for p in (node.get("params") or []) if p not in {"self", "cls"}]
        self.emit_line(f"::method {name}")
        self.indent += 1
        expose = node.get("expose")
        if isinstance(expose, list) and expose:
            self.emit_line("expose " + " ".join(self.rexx_name(x) for x in expose))
        if params:
            self.emit_line("use arg " + ", ".join(params))
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line("/* " + purpose.replace("*/", "* /") + " */")
        body_nodes = node_list(node.get("body"))
        self.emit_block(body_nodes)
        if not self._block_ends_with_return(body_nodes):
            self.emit_line("return .nil")
        self.indent -= 1

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        if op == "class":
            self.emit_class(node)
        elif op == "method":
            self.emit_method(node)
        elif op in {"requires", "require"}:
            return
        else:
            super().emit_node(node)

    def default_for_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t in {"int", "float"}:
            return "0"
        if t == "bool":
            return "0"
        if t == "list":
            return ".array~new"
        if t == "dict":
            return ".directory~new"
        if t.startswith("option") or t == "nullable":
            return ".nil"
        return "''"

    def rexx_literal(self, value: Any) -> str:
        if value is None:
            return ".nil"
        return super().rexx_literal(value)

    def expr(self, value: Any) -> str:
        if isinstance(value, dict):
            op = str(value.get("op", "")).lower()
            if op == "nil":
                return ".nil"
            if op == "new":
                cls = self.rexx_name(value.get("class", value.get("name", "Object")))
                args = ", ".join(self.expr(x) for x in (value.get("args") or []))
                return f".{cls}~new({args})"
            if op == "method":
                obj = self.expr(value.get("obj"))
                method = self.rexx_name(value.get("name", "method"))
                args = ", ".join(self.expr(x) for x in (value.get("args") or []))
                return f"{obj}~{method}({args})"
        return super().expr(value)

class CBackend(Backend):
    """Safe, boring C11 backend for the native Plan42 subset.

    This backend deliberately prefers checked helper calls and clear refusals over
    clever C.  It is a first C membrane: useful for small typed Plan42 programs,
    exact embedded round-trips, and compatibility/preflight work.  Unsupported
    constructs are emitted as comments/no-ops with diagnostics instead of being
    laundered into unsafe pointer behaviour.
    """

    language = "c"
    file_extension = ".c"

    C_KEYWORDS = {
        "auto", "break", "case", "char", "const", "continue", "default", "do",
        "double", "else", "enum", "extern", "float", "for", "goto", "if",
        "inline", "int", "long", "register", "restrict", "return", "short",
        "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
        "unsigned", "void", "volatile", "while", "_Bool", "bool", "true", "false",
    }

    NUMERIC_TYPES = {"int", "float", "bool"}

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        super().__init__(program, include_runtime=include_runtime)
        self.var_types: dict[str, str] = {}
        self.tmp_counter = 0
        self.list_counter = 0
        self.current_function = ""
        self._seed_types()

    def _seed_types(self) -> None:
        for node in self.program.nodes:
            if not isinstance(node, dict):
                continue
            op = str(node.get("op", "")).lower()
            if op in {"const", "declare", "assign"} and node.get("name"):
                typ = canonical_type_name(node.get("type")) or self.infer_type(node.get("value", node.get("expr")))
                if typ:
                    self.var_types[str(node.get("name"))] = typ
            if op == "routine":
                ptypes = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
                for pname, ptype in ptypes.items():
                    self.var_types[str(pname)] = canonical_type_name(ptype) or "str"

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        module = str(self.program.spec.get("module", "Plan42Module"))
        self.emit_line("/* Generated from Plan42 by plan42c.py -- safe C11 target */")
        self.emit_line("/* Module: " + self.safe_comment(module) + " */")
        self._emit_embedded_spec_comments()
        self.emit_line("#include <errno.h>")
        self.emit_line("#include <limits.h>")
        self.emit_line("#include <stdbool.h>")
        self.emit_line("#include <stddef.h>")
        self.emit_line("#include <stdint.h>")
        self.emit_line("#include <stdio.h>")
        self.emit_line("#include <stdlib.h>")
        self.emit_line("#include <string.h>")
        self.emit_line()
        self.emit_runtime_helpers()
        self.emit_line()
        # forward declarations for routines
        for node in self.program.nodes:
            if isinstance(node, dict) and str(node.get("op", "")).lower() == "routine":
                self.emit_line(self.routine_signature(node, prototype=True) + ";")
        if any(isinstance(n, dict) and str(n.get("op", "")).lower() == "routine" for n in self.program.nodes):
            self.emit_line()
        # constants
        for node in self.program.nodes:
            if isinstance(node, dict) and str(node.get("op", "")).lower() == "const":
                self.emit_const(node)
        if any(isinstance(n, dict) and str(n.get("op", "")).lower() == "const" for n in self.program.nodes):
            self.emit_line()
        # routines
        for node in self.program.nodes:
            if not isinstance(node, dict):
                continue
            op = str(node.get("op", "")).lower()
            if op == "routine":
                self.emit_routine(node)
                self.emit_line()
            elif op in {"impl", "const"}:
                continue
            else:
                self.emit_line(f"/* top-level Plan42 op {self.safe_comment(op)} preserved; C backend only executes routines/constants */")
                self.diagnostics.warn(f"C target preserved top-level op as comment: {op}")
        self.emit_c_main()
        return "\n".join(self.lines).rstrip() + "\n"

    def safe_comment(self, text: Any) -> str:
        return str(text).replace("/*", "/ *").replace("*/", "* /").replace("\n", " ")

    def c_name(self, value: Any, fallback: str = "p42_value") -> str:
        s = str(value if value is not None and value != "" else fallback)
        s = re.sub(r"[^0-9A-Za-z_]", "_", s)
        if not s:
            s = fallback
        if s[0].isdigit():
            s = "_" + s
        if s in self.C_KEYWORDS:
            s = s + "_"
        return s

    def c_func_name(self, value: Any) -> str:
        name = self.c_name(value, "routine")
        if name == "main":
            return "p42_user_main"
        return name

    def c_string(self, value: Any) -> str:
        return json.dumps(str(value))

    def _emit_embedded_spec_comments(self) -> None:
        try:
            import base64, gzip
            payload = json.dumps(self.program.spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            encoded = base64.b64encode(gzip.compress(payload, mtime=0)).decode("ascii")
            self.emit_line("/* PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN")
            for i in range(0, len(encoded), 72):
                self.emit_line(encoded[i:i+72])
            self.emit_line("PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END */")
            self.emit_line()
        except Exception as exc:
            self.diagnostics.warn(f"failed to embed Plan42 spec in C output: {exc}")

    def emit_runtime_helpers(self) -> None:
        self.emit_line("#if defined(__GNUC__) || defined(__clang__)")
        self.emit_line("#define P42_UNUSED __attribute__((unused))")
        self.emit_line("#else")
        self.emit_line("#define P42_UNUSED")
        self.emit_line("#endif")
        self.emit_line("typedef struct { const char **data; size_t len; } p42_str_list;")
        self.emit_line("static inline void p42_abort(const char *msg) { fputs(msg ? msg : \"Plan42 C runtime abort\", stderr); fputc('\\n', stderr); exit(42); }")
        self.emit_line("static inline const char *p42_arg(int argc, char **argv, int idx, const char *fallback) { return (idx >= 0 && idx < argc && argv[idx]) ? argv[idx] : fallback; }")
        self.emit_line("static inline long p42_parse_long(const char *s) { char *end = NULL; errno = 0; long v = strtol(s ? s : \"0\", &end, 10); if (errno || (end && *end)) p42_abort(\"invalid integer argument\"); return v; }")
        self.emit_line("static inline bool p42_streq(const char *a, const char *b) { return strcmp(a ? a : \"\", b ? b : \"\") == 0; }")
        self.emit_line("static inline bool p42_str_in(const char *item, const char **items, size_t len) { for (size_t i = 0; i < len; i++) if (p42_streq(item, items[i])) return true; return false; }")
        self.emit_line("static inline long p42_checked_add(long a, long b) {")
        self.emit_line("#if defined(__GNUC__) || defined(__clang__)")
        self.emit_line("    long r; if (__builtin_add_overflow(a, b, &r)) p42_abort(\"checked add overflow\"); return r;")
        self.emit_line("#else")
        self.emit_line("    if ((b > 0 && a > LONG_MAX - b) || (b < 0 && a < LONG_MIN - b)) p42_abort(\"checked add overflow\"); return a + b;")
        self.emit_line("#endif")
        self.emit_line("}")
        self.emit_line("static inline long p42_checked_sub(long a, long b) {")
        self.emit_line("#if defined(__GNUC__) || defined(__clang__)")
        self.emit_line("    long r; if (__builtin_sub_overflow(a, b, &r)) p42_abort(\"checked sub overflow\"); return r;")
        self.emit_line("#else")
        self.emit_line("    if ((b < 0 && a > LONG_MAX + b) || (b > 0 && a < LONG_MIN + b)) p42_abort(\"checked sub overflow\"); return a - b;")
        self.emit_line("#endif")
        self.emit_line("}")
        self.emit_line("static inline long p42_checked_mul(long a, long b) {")
        self.emit_line("#if defined(__GNUC__) || defined(__clang__)")
        self.emit_line("    long r; if (__builtin_mul_overflow(a, b, &r)) p42_abort(\"checked mul overflow\"); return r;")
        self.emit_line("#else")
        self.emit_line("    if (a == 0 || b == 0) return 0; if (a == LONG_MIN && b == -1) p42_abort(\"checked mul overflow\"); if (b == LONG_MIN && a == -1) p42_abort(\"checked mul overflow\");")
        self.emit_line("    if (a > 0) { if (b > 0) { if (a > LONG_MAX / b) p42_abort(\"checked mul overflow\"); } else { if (b < LONG_MIN / a) p42_abort(\"checked mul overflow\"); } }")
        self.emit_line("    else { if (b > 0) { if (a < LONG_MIN / b) p42_abort(\"checked mul overflow\"); } else { if (a != 0 && b < LONG_MAX / a) p42_abort(\"checked mul overflow\"); } } return a * b;")
        self.emit_line("#endif")
        self.emit_line("}")
        self.emit_line("static inline long p42_checked_div(long a, long b) { if (b == 0) p42_abort(\"division by zero\"); return a / b; }")
        self.emit_line("static inline long p42_checked_mod(long a, long b) { if (b == 0) p42_abort(\"modulo by zero\"); return a % b; }")
        self.emit_line("static inline void p42_puts_safe(const char *s) { fputs(s ? s : \"\", stdout); fputc('\\n', stdout); }")

    def c_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t == "int": return "long"
        if t == "float": return "double"
        if t == "bool": return "bool"
        if t == "list": return "p42_str_list"
        if t == "dict": return "void *"
        return "const char *"

    def default_for_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t == "int": return "0"
        if t == "float": return "0.0"
        if t == "bool": return "false"
        if t == "list": return "(p42_str_list){NULL, 0}"
        if t == "dict": return "NULL"
        return "\"\""

    def infer_type(self, value: Any) -> str:
        if isinstance(value, dict):
            op = str(value.get("op", "")).lower()
            if op == "literal":
                declared = canonical_type_name(value.get("type"))
                if declared: return declared
                v = value.get("value")
                if isinstance(v, bool): return "bool"
                if isinstance(v, int): return "int"
                if isinstance(v, float): return "float"
                if isinstance(v, list): return "list"
                if isinstance(v, dict): return "dict"
                if v is None: return "str"
                return "str"
            if op == "var":
                return self.var_types.get(str(value.get("name")), canonical_type_name(value.get("type")) or "str")
            if op in {"add", "sub", "mul", "div", "mod", "len"}: return "int"
            if op in {"eq", "neq", "lt", "lte", "gt", "gte", "and", "or", "not", "in"}: return "bool"
            if op in {"concat", "format", "index", "slice"}: return "str"
            if op == "cast": return canonical_type_name(value.get("to")) or self.infer_type(value.get("expr"))
            if op in {"list", "tuple", "set", "range"}: return "list"
            return "str"
        if isinstance(value, bool): return "bool"
        if isinstance(value, int): return "int"
        if isinstance(value, float): return "float"
        if isinstance(value, list): return "list"
        return "str"

    def emit_const(self, node: dict[str, Any]) -> None:
        name = self.c_name(node.get("name", "CONST"))
        value = node.get("value", {"op":"literal", "value":""})
        typ = canonical_type_name(node.get("type")) or self.infer_type(value)
        self.var_types[str(node.get("name", name))] = typ
        if typ == "list":
            vals = []
            if isinstance(value, dict) and str(value.get("op", "")).lower() == "literal" and isinstance(value.get("value"), list):
                vals = value.get("value")
            arr = name + "_DATA"
            self.emit_line(f"static P42_UNUSED const char *{arr}[] = {{{', '.join(self.c_string(v) for v in vals)}}};")
            self.emit_line(f"static P42_UNUSED const p42_str_list {name} = {{{arr}, sizeof({arr}) / sizeof({arr}[0])}};")
        else:
            self.emit_line(f"static P42_UNUSED const {self.c_type(typ)} {name} = {self.expr(value)};")

    def routine_signature(self, node: dict[str, Any], *, prototype: bool = False) -> str:
        name = self.c_func_name(node.get("name", "routine"))
        params = node.get("params") if isinstance(node.get("params"), list) else []
        ptypes = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
        rendered = []
        for p in params:
            typ = canonical_type_name(ptypes.get(str(p))) or self.var_types.get(str(p), "str")
            rendered.append(f"{self.c_type(typ)} {self.c_name(p)}")
        return f"static void {name}({', '.join(rendered) if rendered else 'void'})"

    def emit_routine(self, node: dict[str, Any]) -> None:
        self.current_function = str(node.get("name", "routine"))
        self.emit_line(self.routine_signature(node) + " {")
        self.indent += 1
        ptypes = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
        for p, t in ptypes.items():
            self.var_types[str(p)] = canonical_type_name(t) or "str"
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1
        self.emit_line("}")
        self.current_function = ""

    def emit_c_main(self) -> None:
        main_node = next((n for n in self.program.nodes if isinstance(n, dict) and str(n.get("op", "")).lower() == "routine" and str(n.get("name", "")).lower() == "main"), None)
        self.emit_line("int main(int argc, char **argv) {")
        self.indent += 1
        self.emit_line("(void)argc;")
        self.emit_line("(void)argv;")
        if main_node is not None:
            args = []
            params = main_node.get("params") if isinstance(main_node.get("params"), list) else []
            ptypes = main_node.get("param_types") if isinstance(main_node.get("param_types"), dict) else {}
            for idx, p in enumerate(params, start=1):
                cname = self.c_name("arg_" + str(p))
                typ = canonical_type_name(ptypes.get(str(p))) or self.var_types.get(str(p), "str")
                if typ == "int":
                    self.emit_line(f"long {cname} = p42_parse_long(p42_arg(argc, argv, {idx}, \"0\"));")
                elif typ == "float":
                    self.emit_line(f"double {cname} = atof(p42_arg(argc, argv, {idx}, \"0\"));")
                elif typ == "bool":
                    self.emit_line(f"bool {cname} = !p42_streq(p42_arg(argc, argv, {idx}, \"\"), \"\");")
                elif typ == "list":
                    self.emit_line(f"p42_str_list {cname} = {{(const char **)(argv + {idx}), (argc > {idx}) ? (size_t)(argc - {idx}) : 0}};")
                else:
                    self.emit_line(f"const char *{cname} = p42_arg(argc, argv, {idx}, \"\");")
                args.append(cname)
            self.emit_line(f"{self.c_func_name('main')}({', '.join(args)});")
        self.emit_line("return 0;")
        self.indent -= 1
        self.emit_line("}")

    def emit_block(self, nodes: list[dict[str, Any]]) -> None:
        if not nodes:
            self.emit_line("/* empty Plan42 block */")
            return
        before = len(self.lines)
        for node in nodes:
            self.emit_node(node)
        if len(self.lines) == before:
            self.emit_line("/* empty Plan42 block */")

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        self.diagnostics.emitted_nodes += 1
        if op == "const":
            self.emit_line(f"/* const {self.safe_comment(node.get('name'))} already emitted at file scope */")
        elif op == "declare":
            name = self.c_name(node.get("name", "value"))
            typ = canonical_type_name(node.get("type")) or self.infer_type(node.get("value", node.get("expr")))
            self.var_types[str(node.get("name", name))] = typ
            value = node.get("value", node.get("expr"))
            self.emit_line(f"{self.c_type(typ)} {name} = {self.expr(value) if value is not None else self.default_for_type(typ)};")
        elif op == "assign":
            target = node.get("target", node.get("name", "value"))
            self.emit_line(f"{self.c_name(target)} = {self.expr(node.get('expr', node.get('value')))};")
        elif op == "return":
            if node.get("expr") is not None or node.get("value") is not None:
                self.diagnostics.warn("C target routines are void in this first backend; return value was ignored")
            self.emit_line("return;")
        elif op == "output":
            self.emit_output(node.get("expr", node.get("value")))
        elif op in {"noop", "pass"}:
            self.emit_line("/* noop */")
        elif op == "assert":
            cond = self.cond_expr(node.get("cond", node.get("expr", {"op":"literal","value":True})))
            msg = node.get("message", {"op":"literal", "value":"Plan42 assertion failed"})
            self.emit_line(f"if (!({cond})) p42_abort({self.expr(msg)});")
        elif op == "if":
            self.emit_if(node)
        elif op == "while":
            self.emit_line(f"while ({self.cond_expr(node.get('cond'))}) {{")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("}")
        elif op == "until":
            self.emit_line(f"while (!({self.cond_expr(node.get('cond'))})) {{")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("}")
        elif op == "for_range":
            self.emit_for_range(node)
        elif op == "for_each":
            self.emit_for_each(node)
        elif op == "break":
            self.emit_line("break;")
        elif op == "continue":
            self.emit_line("continue;")
        elif op in {"match", "select"}:
            self.emit_match(node)
        elif op == "impl_use":
            name = str(node.get("name", ""))
            if name in self.program.routines:
                args = ", ".join(self.expr(a) for a in node.get("args", []))
                self.emit_line(f"{self.c_func_name(name)}({args});")
            else:
                self.emit_line(f"/* unsupported impl_use preserved: {self.safe_comment(name)} */")
                self.diagnostics.unresolved_impls.append(name)
                self.diagnostics.warn(f"C target preserved impl_use as comment: {name}")
        elif op in {"try", "raise", "with", "import", "delete", "expr", "struct", "module"}:
            if op == "module":
                self.emit_block(node_list(node.get("body")))
            elif op == "raise":
                self.emit_line(f"p42_abort({self.expr(node.get('message', node.get('expr', {'op':'literal','value':'Plan42 raise'})))});")
                self.diagnostics.warn("C target lowered raise to p42_abort")
            else:
                self.emit_line(f"/* Plan42 op {self.safe_comment(op)} preserved; no safe C semantics in this backend */")
                self.diagnostics.warn(f"C target preserved unsupported statement as comment: {op}")
        else:
            self.emit_line(f"/* unsupported Plan42 op preserved as no-op: {self.safe_comment(op)} */")
            self.diagnostics.warn(f"C target preserved unsupported op as comment: {op}")

    def emit_if(self, node: dict[str, Any]) -> None:
        self.emit_line(f"if ({self.cond_expr(node.get('cond'))}) {{")
        self.indent += 1
        self.emit_block(node_list(node.get("then")) or node_list(node.get("body")))
        self.indent -= 1
        for branch in node_list(node.get("elif")):
            self.emit_line(f"}} else if ({self.cond_expr(branch.get('cond'))}) {{")
            self.indent += 1
            self.emit_block(node_list(branch.get("body")))
            self.indent -= 1
        else_body = node_list(node.get("else")) or node_list(node.get("else_body"))
        if else_body:
            self.emit_line("} else {")
            self.indent += 1
            self.emit_block(else_body)
            self.indent -= 1
        self.emit_line("}")

    def emit_for_range(self, node: dict[str, Any]) -> None:
        var = self.c_name(node.get("var", "i"))
        start = self.expr(node.get("from", {"op":"literal", "value":0}))
        stop = self.expr(node.get("to", {"op":"literal", "value":0}))
        step = self.expr(node.get("step", {"op":"literal", "value":1}))
        step_name = self.c_name(f"p42_step_{self.tmp_counter}")
        self.tmp_counter += 1
        self.emit_line(f"long {step_name} = {step};")
        self.emit_line(f"if ({step_name} == 0) p42_abort(\"for_range step must not be zero\");")
        self.emit_line(f"for (long {var} = {start}; ({step_name} > 0) ? ({var} < ({stop})) : ({var} > ({stop})); {var} = p42_checked_add({var}, {step_name})) {{")
        self.indent += 1
        self.var_types[var] = "int"
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1
        self.emit_line("}")

    def emit_for_each(self, node: dict[str, Any]) -> None:
        var = self.c_name(node.get("var", node.get("item", "item")))
        coll = node.get("iter_expr", node.get("in", {"op":"literal", "value":[]}))
        vals = None
        if isinstance(coll, dict) and str(coll.get("op", "")).lower() == "literal" and isinstance(coll.get("value"), list):
            vals = [str(v) for v in coll.get("value")]
        if vals is not None:
            arr = self.c_name(f"p42_list_{self.list_counter}")
            self.list_counter += 1
            self.emit_line(f"static P42_UNUSED const char *{arr}[] = {{{', '.join(self.c_string(v) for v in vals)}}};")
            self.emit_line(f"for (size_t {arr}_i = 0; {arr}_i < sizeof({arr}) / sizeof({arr}[0]); {arr}_i++) {{")
            self.indent += 1
            self.emit_line(f"const char *{var} = {arr}[{arr}_i];")
            self.var_types[var] = "str"
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("}")
            return
        if isinstance(coll, dict) and str(coll.get("op", "")).lower() == "var":
            cname = self.c_name(coll.get("name", "items"))
            self.emit_line(f"for (size_t {cname}_i = 0; {cname}_i < {cname}.len; {cname}_i++) {{")
            self.indent += 1
            self.emit_line(f"const char *{var} = {cname}.data[{cname}_i];")
            self.var_types[var] = "str"
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("}")
            return
        self.emit_line("/* unsupported for_each source preserved; no unchecked iteration emitted */")
        self.diagnostics.warn("C target refused unsafe/unknown for_each collection")

    def emit_match(self, node: dict[str, Any]) -> None:
        expr_value = node.get("expr", node.get("value"))
        arms = node.get("arms") if isinstance(node.get("arms"), list) else []
        if arms and expr_value is not None:
            first = True
            for arm in arms:
                if not isinstance(arm, dict):
                    continue
                pat = arm.get("pattern")
                if pat is None:
                    self.emit_line("else {" if not first else "{")
                else:
                    prefix = "if" if first else "else if"
                    self.emit_line(f"{prefix} (p42_streq({self.expr(expr_value)}, {self.c_string(pat)})) {{")
                first = False
                self.indent += 1
                self.emit_block(node_list(arm.get("body")))
                self.indent -= 1
                self.emit_line("}")
            return
        self.emit_line("/* empty/unsupported match preserved */")
        self.diagnostics.warn("C target preserved unsupported match form")

    def emit_output(self, value: Any) -> None:
        if isinstance(value, dict) and str(value.get("op", "")).lower() == "format":
            fmt, args = self.printf_for_format(value)
            self.emit_line(f"printf({self.c_string(fmt + chr(10))}{', ' if args else ''}{', '.join(args)});")
            return
        if isinstance(value, dict) and str(value.get("op", "")).lower() == "concat":
            parts = value.get("args") if isinstance(value.get("args"), list) else [value.get("left"), value.get("right")]
            for part in parts:
                self.emit_printf_part(part)
            self.emit_line("fputc('\\n', stdout);")
            return
        typ = self.infer_type(value)
        code = self.expr(value)
        if typ == "int":
            self.emit_line(f"printf(\"%ld\\n\", {code});")
        elif typ == "float":
            self.emit_line(f"printf(\"%g\\n\", {code});")
        elif typ == "bool":
            self.emit_line(f"p42_puts_safe(({code}) ? \"true\" : \"false\");")
        else:
            self.emit_line(f"p42_puts_safe({code});")

    def emit_printf_part(self, value: Any) -> None:
        typ = self.infer_type(value)
        code = self.expr(value)
        if typ == "int":
            self.emit_line(f"printf(\"%ld\", {code});")
        elif typ == "float":
            self.emit_line(f"printf(\"%g\", {code});")
        elif typ == "bool":
            self.emit_line(f"fputs(({code}) ? \"true\" : \"false\", stdout);")
        else:
            self.emit_line(f"fputs({code}, stdout);")

    def printf_for_format(self, node: dict[str, Any]) -> tuple[str, list[str]]:
        template = str(node.get("template", ""))
        args = node.get("args", {})
        ordered: list[tuple[str, Any]] = []
        if isinstance(args, dict):
            def repl(m):
                key = m.group(1)
                expr = args.get(key, {"op":"literal", "value":""})
                ordered.append((key, expr))
                typ = self.infer_type(expr)
                return "%ld" if typ == "int" else "%g" if typ == "float" else "%s"
            fmt = re.sub(r"\{([^{}]+)\}", repl, template)
        elif isinstance(args, list):
            fmt = template
            for idx, expr in enumerate(args):
                typ = self.infer_type(expr)
                spec = "%ld" if typ == "int" else "%g" if typ == "float" else "%s"
                fmt = fmt.replace("{" + str(idx) + "}", spec)
                ordered.append((str(idx), expr))
        else:
            fmt = template
        rendered_args = []
        for _, expr in ordered:
            typ = self.infer_type(expr)
            code = self.expr(expr)
            if typ == "bool":
                rendered_args.append(f"({code}) ? \"true\" : \"false\"")
            else:
                rendered_args.append(code)
        return fmt, rendered_args

    def expr(self, value: Any) -> str:
        if value is None:
            return "\"\""
        if isinstance(value, str):
            return self.c_name(value)
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, (int, float)):
            return str(value)
        if isinstance(value, list):
            self.diagnostics.warn("C target cannot inline anonymous list except in for_each/in contexts")
            return "(p42_str_list){NULL, 0}"
        if not isinstance(value, dict):
            return self.c_string(value)
        op = str(value.get("op", "")).lower()
        if op == "literal":
            v = value.get("value")
            if v is None: return "\"\""
            if isinstance(v, bool): return "true" if v else "false"
            if isinstance(v, (int, float)): return str(v)
            if isinstance(v, list):
                self.diagnostics.warn("C target cannot use list literal as scalar expression")
                return "(p42_str_list){NULL, 0}"
            return self.c_string(v)
        if op == "nil":
            return "\"\""
        if op == "var":
            return self.c_name(value.get("name", "value"))
        if op == "cast":
            return self.cast_expr(value.get("expr"), value.get("to"))
        if op in {"add", "sub", "mul", "div", "mod"}:
            fn = {"add":"p42_checked_add", "sub":"p42_checked_sub", "mul":"p42_checked_mul", "div":"p42_checked_div", "mod":"p42_checked_mod"}[op]
            return f"{fn}({self.expr(value.get('left'))}, {self.expr(value.get('right'))})"
        if op in {"eq", "neq", "lt", "lte", "gt", "gte", "and", "or", "not", "in"}:
            return self.cond_expr(value)
        if op == "len":
            target = value.get("expr", value.get("value"))
            if isinstance(target, dict) and str(target.get("op", "")).lower() == "var":
                name = self.c_name(target.get("name", "value"))
                typ = self.var_types.get(str(target.get("name")), "")
                if typ == "list":
                    return f"(long){name}.len"
                return f"(long)strlen({name})"
            return "0"
        if op == "ternary":
            return f"({self.cond_expr(value.get('cond'))} ? {self.expr(value.get('then', value.get('true')))} : {self.expr(value.get('else', value.get('false')))})"
        if op == "index":
            obj = value.get("obj", value.get("base"))
            idx = value.get("index")
            if isinstance(obj, dict) and str(obj.get("op", "")).lower() == "var" and self.var_types.get(str(obj.get("name"))) == "list":
                name = self.c_name(obj.get("name"))
                return f"(({self.expr(idx)} >= 0 && (size_t){self.expr(idx)} < {name}.len) ? {name}.data[{self.expr(idx)}] : (p42_abort(\"index out of bounds\"), \"\"))"
            self.diagnostics.warn("C target refused unchecked index expression")
            return "\"\""
        if op == "format":
            self.diagnostics.warn("C target format expression outside output degraded to empty string")
            return "\"\""
        if op == "concat":
            self.diagnostics.warn("C target concat expression outside output degraded to empty string")
            return "\"\""
        if op == "impl_use":
            name = str(value.get("name", ""))
            self.diagnostics.unresolved_impls.append(name)
            return "\"\""
        self.diagnostics.warn(f"C target unsupported expression op {op}; emitted safe default")
        return self.default_for_type(self.infer_type(value))

    def cast_expr(self, expr: Any, to_type: Any) -> str:
        to = canonical_type_name(to_type)
        inner = self.expr(expr)
        if to == "int": return f"((long)({inner}))"
        if to == "float": return f"((double)({inner}))"
        if to == "bool": return f"(({inner}) ? true : false)"
        return inner

    def cond_expr(self, value: Any) -> str:
        if isinstance(value, bool):
            return "true" if value else "false"
        if not isinstance(value, dict):
            return f"({self.expr(value)} != 0)" if isinstance(value, (int, float)) else f"!p42_streq({self.expr(value)}, \"\")"
        op = str(value.get("op", "")).lower()
        if op == "literal":
            v = value.get("value")
            if isinstance(v, bool): return "true" if v else "false"
            if isinstance(v, (int, float)): return f"({v} != 0)"
            return f"!p42_streq({self.c_string(v or '')}, \"\")"
        if op == "var":
            name = str(value.get("name", "value"))
            typ = self.var_types.get(name, canonical_type_name(value.get("type")) or "str")
            code = self.c_name(name)
            if typ == "bool": return code
            if typ in {"int", "float"}: return f"({code} != 0)"
            return f"!p42_streq({code}, \"\")"
        if op in {"eq", "neq"}:
            left, right = value.get("left"), value.get("right")
            if self.infer_type(left) == "str" or self.infer_type(right) == "str":
                cmp = f"p42_streq({self.expr(left)}, {self.expr(right)})"
                return f"!({cmp})" if op == "neq" else cmp
            return f"({self.expr(left)} {'!=' if op == 'neq' else '=='} {self.expr(right)})"
        if op in {"lt", "lte", "gt", "gte"}:
            sym = {"lt":"<", "lte":"<=", "gt":">", "gte":">="}[op]
            return f"({self.expr(value.get('left'))} {sym} {self.expr(value.get('right'))})"
        if op == "and": return f"({self.cond_expr(value.get('left'))} && {self.cond_expr(value.get('right'))})"
        if op == "or": return f"({self.cond_expr(value.get('left'))} || {self.cond_expr(value.get('right'))})"
        if op == "not": return f"!({self.cond_expr(value.get('value', value.get('expr')))})"
        if op == "in":
            item = value.get("item", value.get("left"))
            coll = value.get("collection", value.get("right"))
            if isinstance(coll, dict) and str(coll.get("op", "")).lower() == "literal" and isinstance(coll.get("value"), list):
                vals = [str(v) for v in coll.get("value")]
                arr = "(const char *[]){" + ", ".join(self.c_string(v) for v in vals) + "}"
                return f"p42_str_in({self.expr(item)}, {arr}, {len(vals)})"
            if isinstance(coll, dict) and str(coll.get("op", "")).lower() == "var":
                name = self.c_name(coll.get("name", "items"))
                return f"p42_str_in({self.expr(item)}, {name}.data, {name}.len)"
        return f"!p42_streq({self.expr(value)}, \"\")"


class CppBackend(UnsupportedBackend):
    language = "cpp"
    file_extension = ".cpp"


class JavaBackend(UnsupportedBackend):
    language = "java"
    file_extension = ".java"


class BashBackend(Backend):
    language = "bash"
    file_extension = ".sh"

    BINOPS = {
        "add": "+", "sub": "-", "mul": "*", "div": "/", "mod": "%",
        "eq": "=", "neq": "!=", "lt": "-lt", "lte": "-le", "gt": "-gt", "gte": "-ge",
    }

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        self.emit_line("#!/usr/bin/env bash")
        self.emit_line("# Generated from Plan42 by plan42c.py")
        self.emit_line("set -euo pipefail")
        self.emit_line()
        self._emit_embedded_spec_comments()
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "impl":
                continue
            self.emit_node(node)
            if str(node.get("op", "")).lower() == "routine":
                self.emit_line()
        return "\n".join(self.lines).rstrip() + "\n"

    def _emit_embedded_spec_comments(self) -> None:
        try:
            import base64, gzip
            payload = json.dumps(self.program.spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            encoded = base64.b64encode(gzip.compress(payload, mtime=0)).decode("ascii")
            self.emit_line("# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN")
            for i in range(0, len(encoded), 76):
                self.emit_line("# " + encoded[i:i+76])
            self.emit_line("# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END")
            self.emit_line()
        except Exception as exc:
            self.diagnostics.warn(f"failed to embed Plan42 spec in Bash output: {exc}")

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        self.diagnostics.emitted_nodes += 1
        if op == "const":
            value_node = node.get("value", {"op": "literal", "value": None})
            rendered = self.expr(value_node) if isinstance(value_node, dict) else self.shell_word(value_node)
            self.emit_line(f"readonly {py_name(node.get('name'))}={rendered}")
        elif op == "declare":
            value_node = node.get("value", node.get("expr"))
            rendered = self.expr(value_node) if value_node is not None else self.default_for_type(node.get("type"))
            self.emit_line(f"{py_name(node.get('name', '_'))}={rendered}")
        elif op == "assign":
            target = node.get("target", node.get("name", "_"))
            self.emit_line(f"{py_name(target)}={self.expr(node.get('expr', node.get('value')))}")
        elif op == "routine":
            self.emit_routine(node)
        elif op == "return":
            val = node.get("expr", node.get("value"))
            if val is None:
                self.emit_line("return")
            else:
                self.emit_line(f"printf '%s\\n' {self.expr(val)}")
                self.emit_line("return 0")
        elif op == "output":
            self.emit_line(f"printf '%s\\n' {self.expr(node.get('expr', node.get('value')))}")
        elif op in {"noop", "pass"}:
            self.emit_line(":")
        elif op == "assert":
            cond = self.test_expr(node.get("cond", node.get("expr", {"op":"literal","value":True})))
            msg = node.get("message", {"op":"literal","value":"Plan42 assertion failed"})
            self.emit_line(f"if ! {cond}; then")
            self.indent += 1
            self.emit_line(f"printf '%s\\n' {self.expr(msg)} >&2")
            self.emit_line("return 1 2>/dev/null || exit 1")
            self.indent -= 1
            self.emit_line("fi")
        elif op == "delete":
            target = node.get("target", node.get("name"))
            if isinstance(target, str):
                self.emit_line(f"unset {py_name(target)}")
            else:
                self.emit_line(": # delete target unsupported in Bash")
        elif op == "import":
            self.emit_line(f": # import preserved: {str(node.get('module','')).replace(chr(10),' ')}")
        elif op == "expr":
            self.emit_line(f": # expression preserved: {self.expr(node.get('expr', node.get('value')))}")
        elif op == "call":
            self.emit_line(f": # call expression preserved: {self.expr(node)}")
        elif op == "with":
            self.emit_line(": # with/context manager has no native Bash equivalent; body follows")
            self.emit_block(node_list(node.get("body")))
            self.diagnostics.warn("Bash target degraded with/context manager to body only")
        elif op == "struct":
            self.emit_line(f": # struct {py_name(node.get('name','GeneratedStruct'))} preserved as no-op in Bash")
        elif op == "if":
            self.emit_if(node)
        elif op == "while":
            self.emit_line(f"while {self.test_expr(node.get('cond'))}; do")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("done")
        elif op == "until":
            self.emit_line(f"until {self.test_expr(node.get('cond'))}; do")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("done")
        elif op == "for_each":
            var = py_name(node.get("var", node.get("item", "item")))
            seq = self.iter_words(node.get("iter_expr", node.get("in", {"op":"literal","value":[]})))
            self.emit_line(f"for {var} in {seq}; do")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("done")
        elif op == "for_range":
            var = py_name(node.get("var", "i"))
            start = self.arith_expr(node.get("from", {"op":"literal","value":0}))
            stop = self.arith_expr(node.get("to", {"op":"literal","value":0}))
            step = self.arith_expr(node.get("step", {"op":"literal","value":1}))
            self.emit_line(f"for (( {var}={start}; {var}<{stop}; {var}+={step} )); do")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
            self.emit_line("done")
        elif op == "break":
            self.emit_line("break")
        elif op == "continue":
            self.emit_line("continue")
        elif op == "raise":
            msg = node.get("message", node.get("expr", "Plan42 error"))
            self.emit_line(f"printf '%s\\n' {self.expr(msg)} >&2")
            self.emit_line("return 1")
            self.diagnostics.warn("Bash target lowered raise to stderr + return 1")
        elif op == "try":
            self.emit_line(": # Plan42 try/catch preserved; Bash has no direct exception model")
            self.emit_block(node_list(node.get("body")))
            if node.get("finally") or node.get("finally_body"):
                self.emit_line(": # Plan42 finally")
                self.emit_block(node_list(node.get("finally")) or node_list(node.get("finally_body")))
            self.diagnostics.warn("Bash target preserved try/catch only partially")
        elif op in {"match", "select"}:
            self.emit_match(node)
        elif op == "impl_use":
            self.emit_line(f": # preserved impl_use {str(node.get('name','')).replace(chr(10),' ')}")
            self.diagnostics.warn(f"Bash target preserved impl_use as no-op: {node.get('name')}")
        elif op == "module":
            self.emit_block(node_list(node.get("body")))
        else:
            self.emit_line(f": # unsupported Plan42 op preserved as no-op: {op}")
            self.diagnostics.warn(f"Bash target preserved unsupported op as no-op: {op}")

    def emit_block(self, nodes: list[dict[str, Any]]) -> None:
        if not nodes:
            self.emit_line(":")
            return
        before = len(self.lines)
        for node in nodes:
            self.emit_node(node)
        if len(self.lines) == before:
            self.emit_line(":")

    def emit_routine(self, node: dict[str, Any]) -> None:
        name = py_name(node.get("name", "routine"))
        self.emit_line(f"{name}() {{")
        self.indent += 1
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1
        self.emit_line("}")

    def emit_if(self, node: dict[str, Any]) -> None:
        self.emit_line(f"if {self.test_expr(node.get('cond'))}; then")
        self.indent += 1
        self.emit_block(node_list(node.get("then")) or node_list(node.get("body")))
        self.indent -= 1
        for branch in node_list(node.get("elif")):
            self.emit_line(f"elif {self.test_expr(branch.get('cond'))}; then")
            self.indent += 1
            self.emit_block(node_list(branch.get("body")))
            self.indent -= 1
        else_body = node_list(node.get("else")) or node_list(node.get("else_body"))
        if else_body:
            self.emit_line("else")
            self.indent += 1
            self.emit_block(else_body)
            self.indent -= 1
        self.emit_line("fi")

    def emit_match(self, node: dict[str, Any]) -> None:
        expr_value = node.get("expr", node.get("value"))
        arms = node.get("arms") if isinstance(node.get("arms"), list) else []
        if arms and expr_value is not None:
            self.emit_line(f"case {self.expr(expr_value)} in")
            self.indent += 1
            for arm in arms:
                if not isinstance(arm, dict):
                    continue
                pattern = arm.get("pattern")
                if pattern is None:
                    pat = "*"
                else:
                    pat = str(pattern).replace("\\", "\\\\").replace(")", "\\)")
                self.emit_line(f"{pat})")
                self.indent += 1
                self.emit_block(node_list(arm.get("body")))
                self.emit_line(";;")
                self.indent -= 1
            self.indent -= 1
            self.emit_line("esac")
            return
        # Legacy select form with case conditions.
        cases = node.get("cases") if isinstance(node.get("cases"), list) else []
        emitted = False
        for idx, case in enumerate(cases):
            if not isinstance(case, dict):
                continue
            keyword = "if" if idx == 0 else "elif"
            self.emit_line(f"{keyword} {self.test_expr(case.get('cond'))}; then")
            self.indent += 1
            self.emit_block(node_list(case.get("body")))
            self.indent -= 1
            emitted = True
        default_body = node_list(node.get("default")) or node_list(node.get("else"))
        if default_body:
            self.emit_line("else" if emitted else "if true; then")
            self.indent += 1
            self.emit_block(default_body)
            self.indent -= 1
            emitted = True
        if emitted:
            self.emit_line("fi")
        else:
            self.emit_line(": # empty Plan42 match")

    def shell_word(self, value: Any) -> str:
        if isinstance(value, dict):
            return self.expr(value)
        if isinstance(value, (int, float)):
            return str(value)
        if value is True:
            return "1"
        if value is False or value is None:
            return "''"
        return json.dumps(str(value))

    def default_for_type(self, typ: Any) -> str:
        t = canonical_type_name(typ)
        if t in {"int", "float"}:
            return "0"
        if t == "bool":
            return "0"
        if t == "list":
            return "''"
        if t == "dict":
            return "''"
        return "''"

    def expr(self, value: Any) -> str:
        if value is None:
            return "''"
        if isinstance(value, str):
            return f'"${{{py_name(value)}}}"'
        if not isinstance(value, dict):
            return self.shell_word(value)
        op = str(value.get("op", "")).lower()
        if op == "literal":
            return self.shell_word(value.get("value"))
        if op == "nil":
            return "''"
        if op in {"list", "tuple", "set"}:
            vals = value.get("items") or value.get("values") or []
            return json.dumps(" ".join(str(v.get('value') if isinstance(v, dict) and v.get('op') == 'literal' else self.expr_part(v)) for v in vals))
        if op == "dict":
            self.diagnostics.unresolved_impls.append("dict")
            return "''"
        if op == "attribute":
            self.diagnostics.unresolved_impls.append("attribute")
            return "''"
        if op == "lambda":
            self.diagnostics.unresolved_impls.append("lambda")
            return "''"
        if op in {"list_comp", "set_comp", "dict_comp", "gen_expr", "await", "yield", "walrus"}:
            self.diagnostics.unresolved_impls.append(op)
            return "''"
        if op == "range":
            start = self.arith_expr(value.get("from", {"op":"literal","value":0}))
            stop = self.arith_expr(value.get("to", {"op":"literal","value":0}))
            return f'"$(seq {start} {stop})"'
        if op == "var":
            return f'"${{{py_name(value.get("name", "_"))}}}"'
        if op == "cast":
            return self.expr(value.get("expr"))
        if op in {"add", "sub", "mul", "div", "mod"}:
            return f'"$(({self.arith_expr(value)}))"'
        if op == "concat":
            parts = value.get("args") if isinstance(value.get("args"), list) else [value.get("left"), value.get("right")]
            inner = "".join(self.expr_part(p) for p in parts)
            return json.dumps(inner) if "$" not in inner else f'"{inner}"'
        if op == "format":
            rendered = self.render_format_template(value)
            return json.dumps(rendered) if "$" not in rendered else f'"{rendered}"'
        if op == "in":
            return '"1"' if self.test_expr(value).startswith("[[") else '""'
        if op == "ternary":
            self.diagnostics.warn("Bash expression ternary degraded to then/else textual choice")
            return self.expr(value.get("then", value.get("true", "")))
        if op == "slice":
            self.diagnostics.unresolved_impls.append("slice")
            return '""'
        if op == "len":
            target = value.get("expr", value.get("value"))
            if isinstance(target, dict) and str(target.get("op", "")).lower() == "var":
                return f'"${{#{py_name(target.get("name", "_"))}}}"'
            if isinstance(target, str):
                return f'"${{#{py_name(target)}}}"'
            self.diagnostics.unresolved_impls.append("len")
            return '"0"'
        if op == "index":
            return '""'
        if op == "call":
            self.diagnostics.unresolved_impls.append(str(value.get("routine", value.get("name", "call"))))
            return '""'
        if op == "method" or op == "impl_use" or op == "new":
            self.diagnostics.unresolved_impls.append(str(value.get("name", op)))
            return '""'
        return self.shell_word("")

    def expr_part(self, value: Any) -> str:
        rendered = self.expr(value)
        if rendered.startswith('"') and rendered.endswith('"'):
            return rendered[1:-1]
        if rendered.startswith("'") and rendered.endswith("'"):
            return rendered[1:-1]
        return rendered

    def render_format_template(self, value: dict[str, Any]) -> str:
        template = str(value.get("template", ""))
        args = value.get("args", {})
        if isinstance(args, dict):
            out = template
            for key, expr in args.items():
                out = out.replace("{" + str(key) + "}", self.expr_part(expr))
            return out
        if isinstance(args, list):
            out = template
            for idx, expr in enumerate(args):
                out = out.replace("{" + str(idx) + "}", self.expr_part(expr))
            return out
        return template

    def arith_expr(self, value: Any) -> str:
        if isinstance(value, dict):
            op = str(value.get("op", "")).lower()
            if op == "literal":
                return str(value.get("value", 0))
            if op == "var":
                return py_name(value.get("name", "_"))
            if op in {"add", "sub", "mul", "div", "mod"}:
                sym = {"add":"+", "sub":"-", "mul":"*", "div":"/", "mod":"%"}[op]
                return f"({self.arith_expr(value.get('left'))} {sym} {self.arith_expr(value.get('right'))})"
            if op == "cast":
                return self.arith_expr(value.get("expr"))
        if isinstance(value, str):
            return py_name(value)
        return str(value if value is not None else 0)

    def test_expr(self, value: Any) -> str:
        if isinstance(value, dict):
            op = str(value.get("op", "")).lower()
            if op in {"eq", "neq"}:
                sym = "=" if op == "eq" else "!="
                return f"[[ {self.expr(value.get('left'))} {sym} {self.expr(value.get('right'))} ]]"
            if op in {"lt", "lte", "gt", "gte"}:
                sym = {"lt":"-lt", "lte":"-le", "gt":"-gt", "gte":"-ge"}[op]
                return f"[[ {self.arith_expr(value.get('left'))} {sym} {self.arith_expr(value.get('right'))} ]]"
            if op == "not":
                return f"! {self.test_expr(value.get('value', value.get('expr')))}"
            if op == "and":
                return f"{self.test_expr(value.get('left'))} && {self.test_expr(value.get('right'))}"
            if op == "or":
                return f"{self.test_expr(value.get('left'))} || {self.test_expr(value.get('right'))}"
            if op == "in":
                item = self.expr(value.get("item", value.get("left")))
                item_inner = item[1:-1] if item.startswith('"') and item.endswith('"') else item
                coll = value.get("collection", value.get("right"))
                if isinstance(coll, dict) and str(coll.get("op", "")).lower() == "literal" and isinstance(coll.get("value"), list):
                    words = " ".join(str(x) for x in coll.get("value"))
                    return f"[[ {json.dumps(' ' + words + ' ')} == *\" {item_inner} \"* ]]"
                return f"[[ {self.expr(coll)} == *{item}* ]]"
        return f"[[ -n {self.expr(value)} ]]"

    def iter_words(self, value: Any) -> str:
        if isinstance(value, dict) and str(value.get("op", "")).lower() == "literal" and isinstance(value.get("value"), list):
            return " ".join(json.dumps(str(x)) for x in value.get("value")) or '""'
        if isinstance(value, str):
            return f'"${{{py_name(value)}}}"'
        if isinstance(value, dict) and str(value.get("op", "")).lower() == "var":
            return f'"${{{py_name(value.get("name", "_"))}}}"'
        return self.expr(value)


# ---------------------------------------------------------------------------
# Python 3 backend
# ---------------------------------------------------------------------------


class PythonBackend(Backend):
    language = "python3"
    file_extension = ".py"

    BINOPS = {
        "add": "+", "sub": "-", "mul": "*", "div": "/", "mod": "%",
        "eq": "==", "neq": "!=", "lt": "<", "lte": "<=", "gt": ">", "gte": ">=",
    }

    def __init__(self, program: Plan42Program, *, include_runtime: str = "auto") -> None:
        super().__init__(program, include_runtime=include_runtime)
        self.impl_helper_names: dict[str, str] = {}
        self.required_imports: set[str] = set()
        self.uses_preferred_runtime = False
        self.uses_wik_runtime = False
        if self.program.spec.get("preferreds") or self.program.spec.get("preferred_capabilities"):
            self.uses_preferred_runtime = True

    def compile(self) -> str:
        self.program.validate()
        self.lines = []
        self._scan_runtime_requirements()
        self._emit_header()
        self._emit_embedded_spec_comments()
        self._emit_imports()
        if self._should_include_runtime():
            self._emit_runtime_helpers()
        self._emit_impl_helpers()
        self._emit_top_level_nodes()
        self._emit_entry_guard()
        return "\n".join(self.lines).rstrip() + "\n"

    def _scan_runtime_requirements(self) -> None:
        def walk(value: Any) -> None:
            if isinstance(value, dict):
                op = str(value.get("op", "")).lower()
                name = str(value.get("name", ""))
                if op == "impl_use" and name.startswith("preferred."):
                    self.uses_preferred_runtime = True
                if op == "impl_use" and name.startswith("wik."):
                    self.uses_wik_runtime = True
                for child in value.values():
                    walk(child)
            elif isinstance(value, list):
                for child in value:
                    walk(child)
        walk(self.program.nodes)

    def _should_include_runtime(self) -> bool:
        if self.include_runtime == "always":
            return True
        if self.include_runtime == "never":
            return False
        return self.uses_preferred_runtime or self.uses_wik_runtime

    def _emit_header(self) -> None:
        module = self.program.spec.get("module", "Plan42Module")
        self.emit_line("#!/usr/bin/env python3")
        self.emit_line('"""')
        self.emit_line(f"Generated from Plan42 module: {module}")
        description = str(self.program.spec.get("description", "")).strip()
        if description:
            for line in description.splitlines():
                self.emit_line(line)
        self.emit_line("")
        self.emit_line("This file was emitted by plan42c.py.  Do not hand-edit generated output")
        self.emit_line("unless you are deliberately breaking the Ouroboros loop.")
        self.emit_line('"""')
        self.emit_line()

    def _emit_embedded_spec_comments(self) -> None:
        try:
            import base64, gzip
            payload = json.dumps(self.program.spec, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            encoded = base64.b64encode(gzip.compress(payload, mtime=0)).decode("ascii")
            self.emit_line("# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_BEGIN")
            for i in range(0, len(encoded), 76):
                self.emit_line("# " + encoded[i:i+76])
            self.emit_line("# PLAN42_EMBEDDED_SPEC_GZIP_BASE64_END")
            self.emit_line()
        except Exception as exc:
            self.diagnostics.warn(f"failed to embed Plan42 spec in Python output: {exc}")

    def _emit_imports(self) -> None:
        imports = {"from __future__ import annotations", "from pathlib import Path", "from typing import Any"}
        if self._should_include_runtime():
            imports.update({"import json", "import re", "import sys"})
        imports.update(self.required_imports)
        for line in sorted(imports, key=lambda x: (not x.startswith("from __future__"), x)):
            self.emit_line(line)
        self.emit_line()

    def _emit_runtime_helpers(self) -> None:
        runtime = RUNTIME_HELPERS.strip("\n").splitlines()
        for line in runtime:
            self.emit_line(line)
        self.emit_line()

    def _emit_impl_helpers(self) -> None:
        if not self.program.impls:
            return
        for name in sorted(self.program.impls):
            impl_def = self.program.impls[name]
            helper = self.impl_helper_name(name)
            self.impl_helper_names[name] = helper
            py_impl = impl_def.implementation_for("python3")
            params = ", ".join(py_name(p) for p in impl_def.params)
            self.emit_line(f"def {helper}({params}):")
            self.indent += 1
            if impl_def.abstract:
                self.emit_line(f"# {impl_def.abstract}")
            if py_impl is None:
                self.emit_line(f"raise NotImplementedError({json.dumps('No Python3 implementation for ' + name)})")
                self.diagnostics.unresolved_impls.append(name)
            else:
                self._emit_impl_body(impl_def, py_impl)
            self.indent -= 1
            self.emit_line()
            self.diagnostics.emitted_impl_helpers += 1

    def _emit_impl_body(self, impl_def: ImplDefinition, impl: dict[str, Any]) -> None:
        impl_type = str(impl.get("type", "inline")).lower()
        requires = impl.get("requires")
        if isinstance(requires, list):
            for req in requires:
                r = str(req)
                if r.startswith("import ") or r.startswith("from "):
                    self.emit_line(r)
                else:
                    self.emit_line(f"# requires: {r}")
        if impl_type in {"inline", "library", "command"}:
            inline = impl.get("inline")
            body = impl.get("body")
            if isinstance(body, list):
                self.emit_block(node_list(body))
                return
            if isinstance(inline, str):
                code = self._substitute_impl_placeholders(inline, impl_def.params)
                self._emit_inline_python(code)
                return
            self.emit_line("return None")
            return
        if impl_type == "external_call":
            self._emit_external_call(impl_def, impl)
            return
        if impl_type == "spec":
            nested = impl.get("spec") or impl.get("body")
            if isinstance(nested, dict):
                nested_program = Plan42Program(nested)
                nested_backend = PythonBackend(nested_program, include_runtime=self.include_runtime)
                nested_text = nested_backend.compile()
                self.emit_line("# nested spec implementation omitted from inline helper body")
                self.emit_line("return None")
                self.diagnostics.warn(f"nested spec implementation for {impl_def.name} was not inlined")
                _ = nested_text
                return
            self.emit_line("return None")
            return
        self.emit_line(f"raise NotImplementedError({json.dumps('Unsupported implementation type: ' + impl_type)})")

    def _substitute_impl_placeholders(self, inline: str, params: list[str]) -> str:
        code = inline
        for p in params:
            code = code.replace("{" + p + "}", py_name(p))
        return code

    def _emit_inline_python(self, code: str) -> None:
        stripped = normalise_inline_block(code)
        if not stripped:
            self.emit_line("return None")
            return
        if stripped.startswith("from __future__ import"):
            self.emit_line(f"# skipped future import preserved from impl: {stripped}")
            self.emit_line("return None")
            return
        if is_expr_like_source(stripped):
            self.emit_line("return " + stripped)
            return
        # Statement/block source.  It is emitted inside the helper.  Future
        # imports are intentionally filtered above because Python forbids them
        # inside nested scopes.
        lines = stripped.splitlines()
        for line in lines:
            self.emit_line(line)
        # Make helper bodies valid even for statement-only snippets.
        tail = lines[-1].strip() if lines else ""
        if not tail.startswith(("return", "raise", "yield")):
            self.emit_line("return None")

    def _emit_external_call(self, impl_def: ImplDefinition, impl: dict[str, Any]) -> None:
        command = str(impl.get("command", ""))
        args_template = impl.get("args_template") if isinstance(impl.get("args_template"), list) else []
        self.emit_line("import subprocess")
        args = [command]
        for arg in args_template:
            s = str(arg)
            for p in impl_def.params:
                s = s.replace("{" + p + "}", "{" + py_name(p) + "}")
            args.append(s)
        self.emit_line(f"_cmd = {args!r}")
        for idx, arg in enumerate(args):
            if "{" in arg:
                self.emit_line(f"_cmd[{idx}] = _cmd[{idx}].format(**locals())")
        self.emit_line("_result = subprocess.run(_cmd, capture_output=True, text=True, timeout=60)")
        self.emit_line("return {\"rc\": _result.returncode, \"stdout\": _result.stdout, \"stderr\": _result.stderr}")

    def _emit_top_level_nodes(self) -> None:
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "impl":
                continue
            self.emit_node(node)
            op = str(node.get("op", "")).lower()
            if op in {"routine", "class"}:
                self.emit_line()

    def _emit_entry_guard(self) -> None:
        if "main" not in self.program.routines:
            return
        main_node = None
        for node in self.program.nodes:
            if str(node.get("op", "")).lower() == "routine" and node.get("name") == "main":
                main_node = node
                break
        if main_node is None:
            return
        params = [py_name(p) for p in (main_node.get("params") or [])]
        param_types = main_node.get("param_types") if isinstance(main_node.get("param_types"), dict) else {}
        cli_spec = {}
        preferreds = self.program.spec.get("preferreds", self.program.spec.get("preferred_capabilities", {}))
        if isinstance(preferreds, dict):
            raw_cli = preferreds.get("preferred.cli.parse") or preferreds.get("cli") or {}
            if isinstance(raw_cli, dict):
                cli_spec = raw_cli.get("arguments", raw_cli.get("args", raw_cli)) if isinstance(raw_cli, dict) else {}
        self.emit_line()
        self.emit_line("if __name__ == \"__main__\":")
        self.indent += 1
        self.emit_line("import argparse as _p42_argparse")
        self.emit_line("_p42_parser = _p42_argparse.ArgumentParser()")
        for p in params:
            arg_meta = cli_spec.get(p, {}) if isinstance(cli_spec, dict) else {}
            if not isinstance(arg_meta, dict):
                arg_meta = {}
            typ = canonical_type_name(arg_meta.get("type", param_types.get(p, "str")))
            flag = str(arg_meta.get("flag", "--" + p.replace("_", "-")))
            required = bool(arg_meta.get("required", False))
            has_default = "default" in arg_meta
            default = arg_meta.get("default", False if typ == "bool" else ([] if typ.startswith("list") else ""))
            help_text = str(arg_meta.get("help", ""))
            pieces = [json_literal(flag), f"dest={json_literal(p)}"]
            if help_text and not typ.startswith("list"):
                pieces.append(f"help={json_literal(help_text)}")
            if typ == "bool":
                pieces.append("action='store_true'")
                if has_default:
                    pieces.append(f"default={json_literal(bool(default))}")
            elif typ == "int":
                pieces.append("type=int")
                pieces.append(f"required={required!r}")
                pieces.append(f"default={json_literal(default if has_default else 0 if not required else None)}")
            elif typ == "float":
                pieces.append("type=float")
                pieces.append(f"required={required!r}")
                pieces.append(f"default={json_literal(default if has_default else 0.0 if not required else None)}")
            elif typ.startswith("list"):
                pieces.append("default=" + json_literal(default if has_default else ""))
                pieces.append("help=" + json_literal(help_text + " (comma-separated)" if help_text else "comma-separated"))
            else:
                pieces.append(f"required={required!r}")
                pieces.append(f"default={json_literal(default if has_default else '' if not required else None)}")
            self.emit_line("_p42_parser.add_argument(" + ", ".join(pieces) + ")")
        self.emit_line("_p42_args = _p42_parser.parse_args()")
        for p in params:
            typ = canonical_type_name((cli_spec.get(p, {}) if isinstance(cli_spec, dict) and isinstance(cli_spec.get(p, {}), dict) else {}).get("type", param_types.get(p, "str")))
            if typ.startswith("list"):
                self.emit_line(f"_p42_{p} = _p42_split_cli_list(_p42_args.{p})")
            else:
                self.emit_line(f"_p42_{p} = _p42_args.{p}")
        call_args = ", ".join(f"_p42_{p}" for p in params)
        self.emit_line(f"main({call_args})")
        self.indent -= 1

    def impl_helper_name(self, name: str) -> str:
        return "_p42_impl_" + py_name(name)

    def preferred_helper_name(self, name: str) -> str:
        return "_p42_" + py_name(name.replace("preferred.", "preferred_"))

    def wik_helper_name(self, name: str) -> str:
        return "_p42_" + py_name(name.replace("wik.", "wik_"))

    def emit_node(self, node: dict[str, Any]) -> None:
        op = str(node.get("op", "")).lower()
        self.diagnostics.emitted_nodes += 1
        if op == "const":
            value = node.get("value", {"op": "nil"})
            if isinstance(value, dict) and value.get("op"):
                rendered = self.expr(value)
            else:
                rendered = json_literal(value)
            self.emit_line(f"{py_name(node.get('name'))} = {rendered}")
        elif op == "routine":
            self.emit_routine(node)
        elif op == "class":
            self.emit_class(node)
        elif op == "method":
            self.emit_method(node)
        elif op == "declare":
            name = py_name(node.get("name", "_"))
            value_node = node.get("value", node.get("expr"))
            rendered = typed_default_expr(node.get("type")) if value_node is None else self.expr(value_node)
            annotation = ""
            if node.get("type") and self.include_runtime != "never":
                annotation = f": {py_type_annotation(node.get('type'))}"
            self.emit_line(f"{name}{annotation} = {rendered}")
        elif op == "assign":
            target = node.get("target", node.get("name", "_"))
            if isinstance(target, dict):
                rendered_target = self.expr(target)
            else:
                rendered_target = plan42_name(target)
            self.emit_line(f"{rendered_target} = {self.expr(node.get('expr', node.get('value')))}")
        elif op == "return":
            val = node.get("expr", node.get("value"))
            self.emit_line("return" if val is None else f"return {self.expr(val)}")
        elif op == "output":
            self.emit_line(f"print({self.expr(node.get('expr', node.get('value')))} )".replace(" )", ")"))
        elif op in {"noop", "pass"}:
            self.emit_line("pass")
        elif op == "assert":
            cond = self.expr(node.get("cond", node.get("expr", {"op":"literal","value":True})))
            msg = node.get("message")
            if msg is None:
                self.emit_line(f"assert {cond}")
            else:
                self.emit_line(f"assert {cond}, {self.expr(msg) if isinstance(msg, dict) else json_literal(msg)}")
        elif op == "delete":
            target = node.get("target", node.get("name"))
            if isinstance(target, dict):
                self.emit_line(f"del {self.expr(target)}")
            elif target:
                self.emit_line(f"del {plan42_name(target)}")
            else:
                self.emit_line("pass  # empty delete")
        elif op == "import":
            module = str(node.get("module", "")).strip()
            names = node.get("names") if isinstance(node.get("names"), list) else []
            if names and module:
                rendered = ", ".join(str(x) for x in names)
                self.emit_line(f"from {module} import {rendered}")
            elif module:
                alias = str(node.get("as", "")).strip()
                self.emit_line(f"import {module}" + (f" as {py_name(alias)}" if alias else ""))
            else:
                self.emit_line("pass  # empty import")
        elif op == "expr":
            self.emit_line(self.expr(node.get("expr", node.get("value"))))
        elif op == "call":
            self.emit_line(self.expr(node))
        elif op == "with":
            items = node.get("items") if isinstance(node.get("items"), list) else []
            parts = []
            for item in items:
                if not isinstance(item, dict):
                    continue
                ctx = self.expr(item.get("context", item.get("expr")))
                var = item.get("var", item.get("as"))
                parts.append(f"{ctx} as {py_name(var)}" if var else ctx)
            if not parts:
                parts = [self.expr(node.get("context", node.get("expr", {"op":"literal","value":None})))]
            self.emit_line("with " + ", ".join(parts) + ":")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
        elif op == "struct":
            self.required_imports.add("from dataclasses import dataclass")
            name = py_name(node.get("name", "GeneratedStruct"))
            self.emit_line("@dataclass")
            self.emit_line(f"class {name}:")
            self.indent += 1
            fields = node.get("fields") if isinstance(node.get("fields"), dict) else {}
            if fields:
                for fname, ftype in fields.items():
                    self.emit_line(f"{py_name(fname)}: {py_type_annotation(ftype)} = {typed_default_expr(ftype)}")
            else:
                self.emit_line("pass")
            self.indent -= 1
        elif op == "if":
            self.emit_if(node)
        elif op == "while":
            self.emit_line(f"while {self.expr(node.get('cond'))}:")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
        elif op == "until":
            self.emit_line(f"while not ({self.expr(node.get('cond'))}):")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
        elif op == "for_each":
            var = py_name(node.get("var", node.get("item", "item")))
            iter_value = node.get("iter_expr", node.get("in", {"op": "literal", "value": []}))
            iterable = self.expr(iter_value) if isinstance(iter_value, dict) else plan42_name(iter_value)
            self.emit_line(f"for {var} in {iterable}:")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
        elif op == "for_range":
            var = py_name(node.get("var", "i"))
            start = self.expr(node.get("from", {"op": "literal", "value": 0}))
            stop = self.expr(node.get("to", {"op": "literal", "value": 0}))
            step = node.get("step")
            if step is None:
                self.emit_line(f"for {var} in range({start}, {stop}):")
            else:
                self.emit_line(f"for {var} in range({start}, {stop}, {self.expr(step)}):")
            self.indent += 1
            self.emit_block(node_list(node.get("body")))
            self.indent -= 1
        elif op == "try":
            self.emit_try(node)
        elif op == "raise":
            condition = str(node.get("condition", node.get("type", "Exception")))
            message = node.get("message", node.get("expr", ""))
            if message:
                self.emit_line(f"raise {condition}({self.expr(message) if isinstance(message, dict) else json_literal(message)})")
            else:
                self.emit_line(f"raise {condition}")
        elif op == "break":
            self.emit_line("break")
        elif op == "continue":
            self.emit_line("continue")
        elif op == "impl_use":
            self.emit_impl_use_statement(node)
        elif op == "module":
            self.emit_block(node_list(node.get("body")))
        elif op in {"select", "match"}:
            self.emit_select(node)
        else:
            self.emit_line(f"# unsupported Plan42 op: {op}")
            self.emit_line("pass")
            self.diagnostics.warn(f"unsupported op emitted as pass: {op}")

    def emit_routine(self, node: dict[str, Any]) -> None:
        name = py_name(node.get("name", "routine"))
        param_types = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
        rendered_params = []
        for p in (node.get("params") or []):
            pname = py_name(p)
            if p in param_types:
                rendered_params.append(f"{pname}: {py_type_annotation(param_types[p])}")
            else:
                rendered_params.append(pname)
        params = ", ".join(rendered_params)
        self.emit_line(f"def {name}({params}):")
        self.indent += 1
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line(repr(purpose))
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1

    def emit_class(self, node: dict[str, Any]) -> None:
        name = py_name(node.get("name", "GeneratedClass"))
        parents = [str(p) for p in (node.get("parents") or []) if p]
        parent = py_name(parents[0]) if parents else "object"
        self.emit_line(f"class {name}({parent}):")
        self.indent += 1
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line(repr(purpose))
        emitted = False
        for method in node_list(node.get("methods")):
            self.emit_method(method)
            self.emit_line()
            emitted = True
        residual = node.get("python", {}).get("residual_body") if isinstance(node.get("python"), dict) else None
        if isinstance(residual, list):
            for child in node_list(residual):
                self.emit_node(child)
                emitted = True
        if not emitted:
            self.emit_line("pass")
        self.indent -= 1

    def emit_method(self, node: dict[str, Any]) -> None:
        name = py_name(node.get("name", "method"))
        params = list(node.get("params") or [])
        if not params or params[0] not in {"self", "cls"}:
            params = ["self"] + params
        param_types = node.get("param_types") if isinstance(node.get("param_types"), dict) else {}
        rendered_params = []
        for p in params:
            pname = py_name(p)
            if p in param_types and p not in {"self", "cls"}:
                rendered_params.append(f"{pname}: {py_type_annotation(param_types[p])}")
            else:
                rendered_params.append(pname)
        param_text = ", ".join(rendered_params)
        flags = [str(x).lower() for x in (node.get("flags") or [])]
        prefix = "async def" if "async" in flags else "def"
        self.emit_line(f"{prefix} {name}({param_text}):")
        self.indent += 1
        purpose = str(node.get("business_purpose", "")).strip()
        if purpose:
            self.emit_line(repr(purpose))
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1

    def emit_if(self, node: dict[str, Any]) -> None:
        self.emit_line(f"if {self.expr(node.get('cond'))}:")
        self.indent += 1
        body = node_list(node.get("then")) or node_list(node.get("body"))
        self.emit_block(body)
        self.indent -= 1
        for branch in node_list(node.get("elif")):
            self.emit_line(f"elif {self.expr(branch.get('cond'))}:")
            self.indent += 1
            self.emit_block(node_list(branch.get("body")))
            self.indent -= 1
        else_body = node_list(node.get("else")) or node_list(node.get("else_body"))
        if else_body:
            self.emit_line("else:")
            self.indent += 1
            self.emit_block(else_body)
            self.indent -= 1

    def emit_try(self, node: dict[str, Any]) -> None:
        self.emit_line("try:")
        self.indent += 1
        self.emit_block(node_list(node.get("body")))
        self.indent -= 1
        catches = node_list(node.get("catches"))
        if not catches:
            self.emit_line("except Exception:")
            self.indent += 1
            self.emit_line("raise")
            self.indent -= 1
            return
        for catch in catches:
            condition = str(catch.get("condition", catch.get("type", "Exception")))
            name = catch.get("name", catch.get("var"))
            suffix = f" as {py_name(name)}" if name else ""
            self.emit_line(f"except {condition}{suffix}:")
            self.indent += 1
            self.emit_block(node_list(catch.get("body")))
            self.indent -= 1
        finally_body = node_list(node.get("finally")) or node_list(node.get("finally_body"))
        if finally_body:
            self.emit_line("finally:")
            self.indent += 1
            self.emit_block(finally_body)
            self.indent -= 1

    def emit_select(self, node: dict[str, Any]) -> None:
        arms = node.get("arms") if isinstance(node.get("arms"), list) else []
        match_expr = node.get("expr", node.get("value"))
        if arms and match_expr is not None:
            temp = "_p42_match_value"
            self.emit_line(f"{temp} = {self.expr(match_expr)}")
            emitted_any = False
            for arm in arms:
                if not isinstance(arm, dict):
                    continue
                pattern = arm.get("pattern")
                if pattern is None:
                    self.emit_line("else:")
                else:
                    keyword = "if" if not emitted_any else "elif"
                    pat_expr = self.expr(pattern) if isinstance(pattern, dict) else json_literal(pattern)
                    self.emit_line(f"{keyword} {temp} == {pat_expr}:")
                self.indent += 1
                self.emit_block(node_list(arm.get("body")))
                self.indent -= 1
                emitted_any = True
            if not emitted_any:
                self.emit_line("pass  # empty match")
            return
        cases = node.get("cases") if isinstance(node.get("cases"), list) else []
        emitted_any = False
        for idx, case in enumerate(cases):
            if not isinstance(case, dict):
                continue
            keyword = "if" if idx == 0 else "elif"
            self.emit_line(f"{keyword} {self.expr(case.get('cond'))}:")
            self.indent += 1
            self.emit_block(node_list(case.get("body")))
            self.indent -= 1
            emitted_any = True
        default_body = node_list(node.get("default")) or node_list(node.get("else"))
        if default_body:
            self.emit_line("else:")
            self.indent += 1
            self.emit_block(default_body)
            self.indent -= 1
            emitted_any = True
        if not emitted_any:
            self.emit_line("pass  # empty select")

    def emit_impl_use_statement(self, node: dict[str, Any]) -> None:
        call = self.impl_call_expr(node)
        result = node.get("result")
        if result:
            self.emit_line(f"{py_name(result)} = {call}")
        else:
            self.emit_line(call)

    def expr(self, value: Any) -> str:
        if value is None:
            return "None"
        if isinstance(value, str):
            # Backward compatibility: legacy Plan42 used bare strings as variable
            # references.  New specs should use {"op":"var","name":"..."}
            # or {"op":"literal","value":"...","type":"str"}.
            return plan42_name(value)
        if not isinstance(value, dict):
            return json_literal(value)
        op = str(value.get("op", "")).lower()
        if op == "literal":
            return json_literal(value.get("value"))
        if op == "var":
            return plan42_name(value.get("name", "_"))
        if op == "cast":
            inner = self.expr(value.get("expr"))
            typ = canonical_type_name(value.get("to"))
            casts = {"str": "str", "int": "int", "float": "float", "bool": "bool", "list": "list", "dict": "dict"}
            func = casts.get(typ)
            return f"{func}({inner})" if func else inner
        if op == "nil":
            return "None"
        if op in {"list", "tuple", "set"}:
            items_raw = value.get("items") or value.get("values") or []
            items = ", ".join(self.expr(x) for x in items_raw)
            if op == "list":
                return f"[{items}]"
            if op == "tuple":
                if len(items_raw) == 1:
                    items += ","
                return f"({items})"
            return f"{{{items}}}"
        if op == "dict":
            entries = value.get("entries", value.get("items", {}))
            if isinstance(entries, dict):
                return "{" + ", ".join(f"{json_literal(k)}: {self.expr(v)}" for k, v in entries.items()) + "}"
            parts = []
            for item in entries if isinstance(entries, list) else []:
                if isinstance(item, dict):
                    parts.append(f"{self.expr(item.get('key'))}: {self.expr(item.get('value'))}")
            return "{" + ", ".join(parts) + "}"
        if op == "attribute":
            return f"{self.expr(value.get('obj', value.get('on')))}.{py_name(value.get('name', value.get('attr', '_')))}"
        if op == "lambda":
            params = ", ".join(py_name(p) for p in (value.get("params") or []))
            body = self.expr(value.get("body", {"op":"nil"}))
            return f"(lambda {params}: {body})"
        if op in {"list_comp", "set_comp", "gen_expr"}:
            elt = self.expr(value.get("expr", value.get("elt", {"op":"nil"})))
            var = py_name(value.get("var", "item"))
            iterable = self.expr(value.get("in", value.get("iter", {"op":"literal","value":[]})))
            conds = value.get("ifs") if isinstance(value.get("ifs"), list) else []
            suffix = "".join(" if " + self.expr(c) for c in conds)
            inner = f"{elt} for {var} in {iterable}{suffix}"
            if op == "list_comp":
                return f"[{inner}]"
            if op == "set_comp":
                return f"{{{inner}}}"
            return f"({inner})"
        if op == "dict_comp":
            key = self.expr(value.get("key", {"op":"nil"}))
            val = self.expr(value.get("value", {"op":"nil"}))
            var = py_name(value.get("var", "item"))
            iterable = self.expr(value.get("in", value.get("iter", {"op":"literal","value":[]})))
            conds = value.get("ifs") if isinstance(value.get("ifs"), list) else []
            suffix = "".join(" if " + self.expr(c) for c in conds)
            return f"{{{key}: {val} for {var} in {iterable}{suffix}}}"
        if op == "await":
            return f"(await {self.expr(value.get('expr', value.get('value')))} )".replace(" )", ")")
        if op == "yield":
            expr = value.get("expr", value.get("value"))
            return "yield" if expr is None else f"(yield {self.expr(expr)})"
        if op == "walrus":
            return f"({py_name(value.get('name', '_'))} := {self.expr(value.get('value', value.get('expr')))} )".replace(" )", ")")
        if op == "range":
            args = [value.get("from", {"op":"literal","value":0}), value.get("to"), value.get("step")]
            args = [a for a in args if a is not None]
            return "range(" + ", ".join(self.expr(a) for a in args) + ")"
        if op in self.BINOPS:
            return f"({self.expr(value.get('left'))} {self.BINOPS[op]} {self.expr(value.get('right'))})"
        if op == "and":
            return f"({self.expr(value.get('left'))} and {self.expr(value.get('right'))})"
        if op == "or":
            return f"({self.expr(value.get('left'))} or {self.expr(value.get('right'))})"
        if op == "not":
            inner = value.get("value", value.get("expr"))
            return f"(not {self.expr(inner)})"
        if op == "concat":
            if isinstance(value.get("args"), list):
                parts = [self.expr(x) for x in value.get("args", [])]
            else:
                parts = [self.expr(value.get("left")), self.expr(value.get("right"))]
            return " + ".join(f"str({p})" for p in parts if p != "None") or "''"
        if op == "format":
            template = json_literal(str(value.get("template", "")))
            args = value.get("args", {})
            if isinstance(args, dict):
                rendered = ", ".join(f"{py_name(k)}={self.expr(v)}" for k, v in args.items())
                return f"{template}.format({rendered})"
            if isinstance(args, list):
                rendered = ", ".join(self.expr(v) for v in args)
                return f"{template}.format({rendered})"
            return template
        if op == "in":
            item = self.expr(value.get("item", value.get("left")))
            coll = self.expr(value.get("collection", value.get("right")))
            return f"({item} in {coll})"
        if op == "slice":
            obj = self.expr(value.get("obj", value.get("collection")))
            start = self.expr(value.get("from", value.get("start"))) if value.get("from", value.get("start")) is not None else ""
            stop = self.expr(value.get("to", value.get("end"))) if value.get("to", value.get("end")) is not None else ""
            return f"{obj}[{start}:{stop}]"
        if op == "ternary":
            cond = self.expr(value.get("cond"))
            then = self.expr(value.get("then", value.get("true")))
            other = self.expr(value.get("else", value.get("false")))
            return f"({then} if {cond} else {other})"
        if op == "len":
            return f"len({self.expr(value.get('expr', value.get('value')))} )".replace(" )", ")")
        if op == "call":
            routine = py_name(value.get("routine", value.get("name", "call")))
            args = ", ".join(self.expr(x) for x in (value.get("args") or []))
            return f"{routine}({args})"
        if op == "method":
            obj = self.expr(value.get("obj", value.get("on")))
            name = str(value.get("name", ""))
            args = ", ".join(self.expr(x) for x in (value.get("args") or []))
            return f"{obj}.{name}({args})"
        if op == "new":
            cls = py_name(value.get("class", value.get("name", "object")))
            args = ", ".join(self.expr(x) for x in (value.get("args") or []))
            return f"{cls}({args})"
        if op == "index":
            collection = self.expr(value.get("collection", value.get("obj")))
            key = self.expr(value.get("key", value.get("index")))
            return f"{collection}[{key}]"
        if op == "impl_use":
            return self.impl_call_expr(value)
        self.diagnostics.warn(f"unsupported expression op emitted as None: {op}")
        return "None"

    def impl_call_expr(self, node: dict[str, Any]) -> str:
        name = str(node.get("name", ""))
        args = ", ".join(self.expr(x) for x in (node.get("args") or []))
        if name in self.program.impls:
            return f"{self.impl_helper_name(name)}({args})"
        if name in self.program.routines:
            return f"{py_name(name)}({args})"
        if name.startswith("preferred."):
            return f"{self.preferred_helper_name(name)}({args})"
        if name.startswith("wik."):
            return f"{self.wik_helper_name(name)}({args})"
        self.diagnostics.unresolved_impls.append(name)
        return f"_p42_unresolved_impl({json_literal(name)}, {args})"


RUNTIME_HELPERS = r'''

def _p42_unresolved_impl(name, *args):
    raise NotImplementedError(f"Plan42 implementation is unresolved: {name} args={args!r}")


def _p42_preferred_file_stream_lines(input_path):
    with open(input_path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            yield line


def _p42_preferred_data_jsonl_parse(raw_line):
    raw = raw_line.strip()
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None


def _p42_preferred_ui_progress(line_n, progress_interval, message=""):
    try:
        interval = int(progress_interval)
    except Exception:
        interval = 0
    if interval > 0 and int(line_n) % interval == 0:
        print(f"[plan42] {line_n}: {message}", file=sys.stderr)


def _p42_preferred_file_multiwrite_open(output_dir, target_langs, kinds):
    root = Path(output_dir)
    root.mkdir(parents=True, exist_ok=True)
    handles = {}
    for lang in target_langs:
        for kind in kinds:
            path = root / f"{lang}.{kind}"
            handles[(lang, kind)] = path.open("w", encoding="utf-8")
    return handles


def _p42_preferred_file_multiwrite_write(handles, lang, kind, text):
    handle = handles.get((lang, kind))
    if handle is None:
        raise KeyError(f"no Plan42 multiwrite handle for {(lang, kind)!r}")
    handle.write(str(text))


def _p42_preferred_file_multiwrite_close(handles):
    for handle in handles.values():
        handle.close()


def _p42_preferred_file_write_tsv(rows, path):
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        if isinstance(rows, dict):
            for key in sorted(rows):
                value = rows[key]
                if isinstance(value, (list, tuple, set)):
                    value = " ".join(str(x) for x in value)
                f.write(f"{key}\t{value}\n")
        else:
            for row in rows:
                if isinstance(row, (list, tuple)):
                    f.write("\t".join(str(x) for x in row) + "\n")
                else:
                    f.write(str(row) + "\n")


def _p42_soundex_key(text):
    s = re.sub(r"[^A-Za-z]", "", str(text).upper())
    if not s:
        s = re.sub(r"\s+", "", str(text).upper())[:1] or "_"
    first = s[0]
    table = str.maketrans({
        "B":"1","F":"1","P":"1","V":"1",
        "C":"2","G":"2","J":"2","K":"2","Q":"2","S":"2","X":"2","Z":"2",
        "D":"3","T":"3","L":"4","M":"5","N":"5","R":"6",
    })
    digits = s.translate(table)
    compact = []
    last = ""
    for ch in digits[1:]:
        if ch.isdigit() and ch != last:
            compact.append(ch)
        last = ch
    return (first + "".join(compact) + "000")[:4]


def _p42_preferred_data_soundex_from_ipa(output_dir, lang):
    path = Path(output_dir) / f"{lang}.ipa"
    buckets = {}
    if not path.exists():
        return buckets
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or "\t" not in line:
                continue
            word, ipa = line.split("\t", 1)
            key = _p42_soundex_key(ipa or word)
            buckets.setdefault(key, []).append(word)
    return buckets


_P42_TOPIC_NOISE = {
    "noun", "verb", "adjective", "adverb", "proper", "pronoun", "article",
    "preposition", "conjunction", "interjection", "particle", "determiner",
    "plural", "singular", "masculine", "feminine", "neuter", "common",
    "uncountable", "countable", "transitive", "intransitive", "obsolete",
}


def _normalise_topic(raw):
    text = str(raw or "").strip().lower()
    text = re.sub(r"^[a-z]{2,5}[:_/ -]+", "", text)
    text = re.sub(r"[^\w\s-]+", " ", text, flags=re.UNICODE)
    words = [w for w in re.split(r"\s+", text) if w and w not in _P42_TOPIC_NOISE]
    if not words:
        return ""
    topic = " ".join(words).strip()
    return topic if len(topic) >= 3 else ""


def _extract_topics(entry):
    found = set()
    def add(value):
        if isinstance(value, str):
            n = _normalise_topic(value)
            if n:
                found.add(n)
        elif isinstance(value, list):
            for item in value:
                add(item)
    for key in ("topics", "categories", "tags", "raw_tags"):
        add(entry.get(key))
    for sense in entry.get("senses", []) or []:
        if not isinstance(sense, dict):
            continue
        for key in ("topics", "categories", "tags", "raw_tags"):
            add(sense.get(key))
        for gloss in sense.get("glosses", []) or []:
            if isinstance(gloss, str) and len(gloss) <= 80:
                add(gloss)
    return sorted(found)


def _first_ipa(entry):
    for sound in entry.get("sounds", []) or []:
        if not isinstance(sound, dict):
            continue
        ipa = sound.get("ipa") or sound.get("enpr") or ""
        if ipa:
            return str(ipa).strip("/[] ")
    return ""


def _p42_collapse_tsv(path, merge=False):
    p = Path(path)
    if not p.exists():
        return
    rows = {}
    order = []
    with p.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            if "\t" in line:
                key, value = line.split("\t", 1)
            else:
                key, value = line, ""
            if key not in rows:
                rows[key] = set() if merge else value
                order.append(key)
            if merge:
                rows[key].update(x for x in value.split() if x)
    with p.open("w", encoding="utf-8") as f:
        for key in order:
            value = " ".join(sorted(rows[key])) if merge else rows[key]
            f.write(f"{key}\t{value}\n")


def _p42_wik_collapse_words(output_dir, lang):
    _p42_collapse_tsv(Path(output_dir) / f"{lang}.words", merge=False)


def _p42_wik_collapse_scope(output_dir, lang):
    _p42_collapse_tsv(Path(output_dir) / f"{lang}.scope", merge=True)


def _p42_wik_collapse_ipa(output_dir, lang):
    _p42_collapse_tsv(Path(output_dir) / f"{lang}.ipa", merge=False)

def _p42_split_cli_list(value):
    if value is None or value == "":
        return []
    if isinstance(value, (list, tuple)):
        return [str(x) for x in value]
    return [x.strip() for x in str(value).split(",") if x.strip()]


def _p42_preferred_log_debug(message, context=None):
    import logging as _logging
    _logging.getLogger("plan42").debug(str(message), extra={"plan42_context": context or {}})


def _p42_preferred_log_info(message, context=None):
    import logging as _logging
    _logging.getLogger("plan42").info(str(message), extra={"plan42_context": context or {}})


def _p42_preferred_log_warn(message, context=None):
    import logging as _logging
    _logging.getLogger("plan42").warning(str(message), extra={"plan42_context": context or {}})


def _p42_preferred_log_error(message, context=None):
    import logging as _logging
    _logging.getLogger("plan42").error(str(message), extra={"plan42_context": context or {}})


def _p42_preferred_log_fatal(message, context=None):
    import logging as _logging
    _logging.getLogger("plan42").critical(str(message), extra={"plan42_context": context or {}})
    raise SystemExit(1)


def _p42_preferred_log_structured(level, event, fields=None):
    import logging as _logging
    payload = {"event": str(event), "fields": fields or {}}
    _logging.getLogger("plan42").log(getattr(_logging, str(level).upper(), _logging.INFO), json.dumps(payload, sort_keys=True))


def _p42_preferred_json_parse(text):
    return json.loads(text)


def _p42_preferred_json_stringify(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def _p42_preferred_json_read(path):
    with Path(path).open("r", encoding="utf-8") as _f:
        return json.load(_f)


def _p42_preferred_json_write(value, path):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as _f:
        json.dump(value, _f, ensure_ascii=False, sort_keys=True, indent=2)
        _f.write("\n")


def _p42_preferred_json_write_atomic(value, path):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    _p42_preferred_json_write(value, tmp)
    tmp.replace(p)


def _p42_preferred_api_adapter(config):
    if not isinstance(config, dict):
        raise TypeError("preferred.api.adapter expects a dict")
    out = dict(config)
    out.setdefault("timeout", 30)
    out.setdefault("headers", {})
    out.setdefault("audit", True)
    return out


def _p42_preferred_api_auth_bearer(token):
    if not token:
        raise ValueError("empty bearer token refused")
    return {"Authorization": "Bearer " + str(token)}


def _p42_preferred_api_validate_request(schema, payload):
    # Minimal structural validator.  Full schema engines belong behind backend
    # libraries; this catches required keys without inventing a schema dialect.
    if not isinstance(schema, dict):
        return True
    required = schema.get("required", [])
    missing = [k for k in required if not isinstance(payload, dict) or k not in payload]
    if missing:
        raise ValueError("API request missing required keys: " + ", ".join(map(str, missing)))
    return True


def _p42_preferred_api_validate_response(schema, payload):
    return _p42_preferred_api_validate_request(schema, payload)


def _p42_preferred_api_map_error(status, body=None):
    return {"status": int(status), "body": body, "retryable": int(status) in {408, 409, 425, 429, 500, 502, 503, 504}}


def _p42_preferred_api_audit_call(name, details=None):
    _p42_preferred_log_structured("info", "api.call", {"name": name, "details": details or {}})


def _p42_preferred_api_request(adapter, endpoint, params=None):
    import urllib.parse as _urlparse
    import urllib.request as _urlrequest
    cfg = _p42_preferred_api_adapter(adapter)
    base = str(cfg.get("base_url", "")).rstrip("/")
    if not base:
        raise ValueError("preferred.api.request requires base_url")
    endpoint_text = str(endpoint).lstrip("/")
    url = base + "/" + endpoint_text
    method = str(cfg.get("method", "GET")).upper()
    headers = dict(cfg.get("headers", {}))
    timeout = int(cfg.get("timeout", 30))
    data = None
    if method == "GET" and params:
        url += ("&" if "?" in url else "?") + _urlparse.urlencode(params)
    elif params is not None:
        data = json.dumps(params).encode("utf-8")
        headers.setdefault("Content-Type", "application/json")
    req = _urlrequest.Request(url, data=data, headers=headers, method=method)
    if cfg.get("audit", True):
        _p42_preferred_api_audit_call(endpoint_text, {"method": method})
    with _urlrequest.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
        text = raw.decode("utf-8", errors="replace")
        ctype = resp.headers.get("Content-Type", "")
        if "json" in ctype.lower():
            try:
                return json.loads(text)
            except Exception:
                return text
        return text


def _p42_preferred_api_get(adapter, endpoint, params=None):
    cfg = dict(adapter)
    cfg["method"] = "GET"
    return _p42_preferred_api_request(cfg, endpoint, params)


def _p42_preferred_api_post(adapter, endpoint, payload=None):
    cfg = dict(adapter)
    cfg["method"] = "POST"
    return _p42_preferred_api_request(cfg, endpoint, payload)
'''


# ---------------------------------------------------------------------------
# Compatibility preflight
# ---------------------------------------------------------------------------

STATEMENT_OPS = {
    "const", "declare", "assign", "routine", "class", "method", "struct", "return",
    "output", "noop", "pass", "assert", "delete", "import", "expr", "with",
    "if", "while", "until", "for_each", "for_range", "try",
    "catch", "raise", "break", "continue", "module", "select", "match", "impl", "impl_use",
}
EXPRESSION_OPS = {
    "literal", "var", "cast", "nil", "add", "sub", "mul", "div", "mod",
    "eq", "neq", "lt", "lte", "gt", "gte", "and", "or", "not",
    "concat", "format", "in", "index", "slice", "ternary", "len",
    "call", "method", "new", "attribute", "lambda", "list", "tuple", "set", "dict",
    "list_comp", "set_comp", "dict_comp", "gen_expr", "await", "yield", "walrus", "range", "impl_use",
}
PYTHON_NATIVE_OPS = STATEMENT_OPS | EXPRESSION_OPS
BASH_NATIVE_STATEMENTS = {"const", "declare", "assign", "routine", "return", "output", "noop", "pass", "assert", "delete", "if", "while", "until", "for_each", "for_range", "break", "continue", "module", "match", "select"}
BASH_NATIVE_EXPRS = {"literal", "var", "cast", "nil", "add", "sub", "mul", "div", "mod", "eq", "neq", "lt", "lte", "gt", "gte", "not", "and", "or", "concat", "format", "in", "len", "list", "tuple", "set", "range"}
CLASSIC_REXX_NATIVE_STATEMENTS = {"const", "declare", "assign", "routine", "return", "output", "noop", "pass", "assert", "delete", "if", "while", "until", "for_each", "for_range", "break", "continue", "module", "match", "select", "raise"}
CLASSIC_REXX_NATIVE_EXPRS = {"literal", "var", "cast", "nil", "add", "sub", "mul", "div", "mod", "eq", "neq", "lt", "lte", "gt", "gte", "not", "and", "or", "concat", "format", "in", "len", "slice", "ternary", "list", "tuple", "set", "call", "impl_use"}
OOREXX_NATIVE_STATEMENTS = CLASSIC_REXX_NATIVE_STATEMENTS | {"class", "method"}
OOREXX_NATIVE_EXPRS = CLASSIC_REXX_NATIVE_EXPRS | {"method", "new", "attribute"}
RUST_NATIVE_STATEMENTS = {"const", "declare", "assign", "routine", "return", "output", "noop", "pass", "assert", "if", "while", "for_each", "for_range", "break", "continue", "raise", "impl", "impl_use"}
RUST_NATIVE_EXPRS = {"literal", "var", "cast", "nil", "add", "sub", "mul", "div", "mod", "eq", "neq", "lt", "lte", "gt", "gte", "not", "and", "or", "concat", "format", "in", "len", "index", "ternary", "list", "tuple", "set", "call", "impl_use"}
C_NATIVE_STATEMENTS = {"const", "declare", "assign", "routine", "return", "output", "noop", "pass", "assert", "if", "while", "until", "for_each", "for_range", "break", "continue", "module", "match", "select", "raise", "impl", "impl_use"}
C_NATIVE_EXPRS = {"literal", "var", "cast", "nil", "add", "sub", "mul", "div", "mod", "eq", "neq", "lt", "lte", "gt", "gte", "not", "and", "or", "concat", "format", "in", "len", "index", "ternary", "list", "tuple", "set"}


def _walk_plan42(value: Any, path: str = "$") -> Iterable[tuple[str, dict[str, Any]]]:
    if isinstance(value, dict):
        if isinstance(value.get("op"), str):
            yield path, value
        for k, v in value.items():
            if isinstance(v, (dict, list)):
                yield from _walk_plan42(v, f"{path}.{k}")
    elif isinstance(value, list):
        for i, item in enumerate(value):
            yield from _walk_plan42(item, f"{path}[{i}]")


def target_compatibility(program: Plan42Program, target: str) -> dict[str, Any]:
    raw_target = target.strip().lower()
    t = normalise_target(target)
    display_target = "regina" if t == "classicrexx" and raw_target in {"regina", "rexx"} else t
    issues: list[dict[str, Any]] = []
    by_kind: dict[str, int] = {}

    def issue(kind: str, severity: str, path: str, op: str, reason: str) -> None:
        by_kind[kind] = by_kind.get(kind, 0) + 1
        issues.append({"kind": kind, "severity": severity, "path": path, "op": op, "reason": reason})

    for path, node in _walk_plan42(program.spec):
        op = str(node.get("op", "")).lower()
        if op == "impl":
            impls = node.get("implementations") if isinstance(node.get("implementations"), dict) else {}
            aliases = [t] + (["python", "py"] if t == "python3" else []) + (["sh"] if t == "bash" else []) + (["rexx", "regina", "classic-rexx", "classic_rexx"] if t == "classicrexx" else []) + (["oo_rexx", "oo-rexx", "orx"] if t == "oorexx" else []) + (["c11"] if t == "c" else [])
            if not any(isinstance(impls.get(a), dict) for a in aliases):
                issue("missing_impl_for_target", "high", path, op, f"impl {node.get('name')} has no {t} implementation")
        elif op == "impl_use":
            name = str(node.get("name", ""))
            if name in program.impls:
                impl = program.impls[name].implementation_for(t)
                if impl is None:
                    issue("unresolved_impl_use", "high", path, op, f"impl_use {name} has no {t} implementation")
            elif name.startswith("preferred.") or name.startswith("wik."):
                if t not in {"python3"}:
                    issue("runtime_unresolved", "high", path, op, f"preferred/wik helper {name} is implemented only by Python runtime in this drop")
            elif name not in program.routines:
                issue("runtime_unresolved", "high", path, op, f"impl_use {name} is not known as impl or routine")
        elif t == "python3":
            if op and op not in PYTHON_NATIVE_OPS:
                issue("unsupported_op", "medium", path, op, "Python backend will preserve or no-op unsupported node")
        elif t == "bash":
            # A simple role classifier: expression-only ops are fine only when nested.
            if op in STATEMENT_OPS and op not in BASH_NATIVE_STATEMENTS and op != "impl":
                issue("degraded_statement", "medium", path, op, "Bash backend preserves this statement without native semantics")
            elif op in EXPRESSION_OPS and op not in BASH_NATIVE_EXPRS:
                issue("degraded_expression", "medium", path, op, "Bash backend cannot natively carry this expression")
        elif t == "classicrexx":
            if op in STATEMENT_OPS and op not in CLASSIC_REXX_NATIVE_STATEMENTS and op != "impl":
                issue("degraded_statement", "medium", path, op, "Classic REXX backend preserves this statement without native semantics")
            elif op in EXPRESSION_OPS and op not in CLASSIC_REXX_NATIVE_EXPRS:
                issue("degraded_expression", "medium", path, op, "Classic REXX backend cannot natively carry this expression")
        elif t == "oorexx":
            if op in STATEMENT_OPS and op not in OOREXX_NATIVE_STATEMENTS and op != "impl":
                issue("degraded_statement", "medium", path, op, "ooRexx backend preserves this statement without native semantics")
            elif op in EXPRESSION_OPS and op not in OOREXX_NATIVE_EXPRS:
                issue("degraded_expression", "medium", path, op, "ooRexx backend cannot natively carry this expression")
        elif t == "rust":
            if op in STATEMENT_OPS and op not in RUST_NATIVE_STATEMENTS and op != "impl":
                issue("degraded_statement", "medium", path, op, "Rust scaffold preserves this statement without native semantics")
            elif op in EXPRESSION_OPS and op not in RUST_NATIVE_EXPRS:
                issue("degraded_expression", "medium", path, op, "Rust scaffold cannot natively carry this expression yet")
        elif t == "c":
            if op in STATEMENT_OPS and op not in C_NATIVE_STATEMENTS and op != "impl":
                issue("degraded_statement", "medium", path, op, "C backend preserves this statement without native semantics")
            elif op in EXPRESSION_OPS and op not in C_NATIVE_EXPRS:
                issue("degraded_expression", "medium", path, op, "C backend cannot natively carry this expression safely yet")
        else:
            issue("backend_not_ready", "high", path, op, f"{t} backend is registered but not implemented")

    high = any(i["severity"] == "high" for i in issues)
    medium = any(i["severity"] == "medium" for i in issues)
    if high:
        status = "runtime_unresolved"
    elif medium:
        status = "degraded_but_reversible"
    else:
        status = "native"
    return {
        "target": display_target,
        "status": status,
        "issues": issues,
        "by_kind": by_kind,
        "unresolved_impls": sum(1 for i in issues if "impl" in i["kind"] or i["kind"] == "runtime_unresolved"),
        "unsupported_nodes": sum(1 for i in issues if i["kind"].startswith("unsupported") or i["kind"].startswith("degraded")),
    }


def compatibility_report(program: Plan42Program, targets: list[str]) -> dict[str, Any]:
    results = [target_compatibility(program, target) for target in targets]
    return {
        "schema": "plan42.compatibility_report.v1",
        "module": program.spec.get("module"),
        "summary": {r["target"]: {
            "status": r["status"],
            "issues": len(r["issues"]),
            "unresolved_impls": r["unresolved_impls"],
            "unsupported_nodes": r["unsupported_nodes"],
        } for r in results},
        "results": results,
    }


# ---------------------------------------------------------------------------
# Backend factory and command actions
# ---------------------------------------------------------------------------


def backend_for(target: str, program: Plan42Program, *, include_runtime: str = "auto") -> Backend:
    t = normalise_target(target)
    if t == "python3":
        return PythonBackend(program, include_runtime=include_runtime)
    if t == "rust":
        return RustBackend(program, include_runtime=include_runtime)
    if t == "oorexx":
        return OORexxBackend(program, include_runtime=include_runtime)
    if t == "classicrexx":
        return ClassicRexxBackend(program, include_runtime=include_runtime)
    if t == "c":
        return CBackend(program, include_runtime=include_runtime)
    if t == "cpp":
        return CppBackend(program, include_runtime=include_runtime)
    if t == "java":
        return JavaBackend(program, include_runtime=include_runtime)
    if t == "bash":
        return BashBackend(program, include_runtime=include_runtime)
    raise ValueError(f"unknown target backend: {target}")


def compile_plan42(input_path: Path, output_path: Optional[Path], *, target: str, include_runtime: str, diagnostics_path: Optional[Path] = None, compatibility_path: Optional[Path] = None, fail_on_incompatible: bool = False) -> int:
    program = Plan42Program(read_json(input_path))
    compat = target_compatibility(program, target)
    if compatibility_path:
        write_text(compatibility_path, json.dumps(compat, indent=2, ensure_ascii=False) + "\n")
    if fail_on_incompatible and compat.get("status") != "native":
        print(f"plan42c: target {normalise_target(target)} is not natively compatible: {compat.get('status')}", file=sys.stderr)
        return 5
    backend = backend_for(target, program, include_runtime=include_runtime)
    try:
        text = backend.compile()
    except NotImplementedError as exc:
        print(f"plan42c: {exc}", file=sys.stderr)
        return 3
    write_text(output_path, text)
    if diagnostics_path:
        write_text(diagnostics_path, json.dumps(backend.diagnostics.as_dict(), indent=2, ensure_ascii=False) + "\n")
    return 0


def py_compile_check(path: Path) -> tuple[bool, str]:
    proc = subprocess.run([sys.executable, "-m", "py_compile", str(path)], text=True, capture_output=True)
    return proc.returncode == 0, (proc.stderr or proc.stdout)


def run_py2plan42(py2plan42: Path, source: Path, out_spec: Path, module: str) -> None:
    proc = subprocess.run(
        [sys.executable, str(py2plan42), str(source), "--module", module, "-o", str(out_spec)],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"py2plan42 failed rc={proc.returncode}\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}")


def run_ouroboros(source_py: Path, *, py2plan42: Path, workdir: Path, include_runtime: str) -> dict[str, Any]:
    workdir.mkdir(parents=True, exist_ok=True)
    spec1_path = workdir / "round1.plan42.json"
    gen_py_path = workdir / "round2.generated.py"
    spec2_path = workdir / "round3.plan42.json"
    diag_path = workdir / "round2.diagnostics.json"

    module = py_name(source_py.stem, fallback="OuroborosModule")
    run_py2plan42(py2plan42, source_py, spec1_path, module)
    rc = compile_plan42(spec1_path, gen_py_path, target="python3", include_runtime=include_runtime, diagnostics_path=diag_path)
    if rc != 0:
        raise RuntimeError(f"plan42 compile failed rc={rc}")
    py_ok, py_msg = py_compile_check(gen_py_path)
    # Feed the generated Python back into py2plan42.  This deliberately tests
    # whether the compiler emits parseable Python that can re-enter the loop.
    if py_ok:
        run_py2plan42(py2plan42, gen_py_path, spec2_path, module + "RoundTrip")

    spec1 = Plan42Program(read_json(spec1_path))
    spec2 = Plan42Program(read_json(spec2_path)) if spec2_path.exists() else None
    report = {
        "status": "pass" if py_ok and spec2 is not None else "fail",
        "source": str(source_py),
        "workdir": str(workdir),
        "artifacts": {
            "round1_spec": str(spec1_path),
            "round2_python": str(gen_py_path),
            "round2_diagnostics": str(diag_path),
            "round3_spec": str(spec2_path) if spec2_path.exists() else None,
        },
        "python_compile": {"ok": py_ok, "message": py_msg},
        "round1": spec1.feature_summary(),
        "round3": spec2.feature_summary() if spec2 is not None else None,
        "semantic_checks": {},
    }
    if spec2 is not None:
        r1 = spec1.feature_summary()
        r3 = spec2.feature_summary()
        for key in ("routines", "classes", "constants"):
            missing = sorted(set(r1[key]) - set(r3[key]))
            report["semantic_checks"][key + "_missing_after_roundtrip"] = missing
        report["semantic_checks"]["roundtrip_node_count_delta"] = int(r3["node_count"]) - int(r1["node_count"])
        if any(report["semantic_checks"][k] for k in report["semantic_checks"] if k.endswith("missing_after_roundtrip")):
            report["status"] = "fail"
    return report


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Compile Plan42 JSON specs to target source code. Current full backend: Python3; Rust is scaffold/static.")
    parser.add_argument("input", nargs="?", help="Plan42 JSON input file")
    parser.add_argument("-o", "--output", help="Generated source output path. Defaults to stdout.")
    parser.add_argument("--target", default="python3", help="Target backend: python3, bash, classicrexx, oorexx, c ready/static; rust scaffold/static; cpp/java registered.")
    parser.add_argument("--runtime", choices=["auto", "always", "never"], default="auto", help="Include generated Python runtime helpers.")
    parser.add_argument("--diagnostics", help="Write compiler diagnostics JSON.")
    parser.add_argument("--compatibility", help="Write target compatibility preflight JSON.")
    parser.add_argument("--fail-on-incompatible", action="store_true", help="Return rc=5 before emission when target compatibility is not native.")
    parser.add_argument("--list-targets", action="store_true", help="List registered targets and exit.")
    parser.add_argument("--ouroboros", metavar="SOURCE.py", help="Run Python -> Plan42 -> Python -> Plan42 round-trip check.")
    parser.add_argument("--py2plan42", default="py2plan42.py", help="Path to py2plan42.py for --ouroboros.")
    parser.add_argument("--workdir", default=".plan42_ouroboros", help="Work directory for --ouroboros artifacts.")
    parser.add_argument("--stats", action="store_true", help="Print diagnostics/report JSON to stderr.")
    args = parser.parse_args(argv)

    if args.list_targets:
        for target in sorted(KNOWN_TARGETS):
            normal = normalise_target(target)
            if normal in {"python3", "bash", "classicrexx", "oorexx", "c"}:
                marker = "ready"
            elif normal == "rust":
                marker = "scaffold"
            else:
                marker = "registered"
            print(f"{target}\t{marker}")
        return 0

    if args.ouroboros:
        try:
            report = run_ouroboros(Path(args.ouroboros), py2plan42=Path(args.py2plan42), workdir=Path(args.workdir), include_runtime=args.runtime)
        except Exception as exc:
            print(f"plan42c ouroboros failed: {exc}", file=sys.stderr)
            return 2
        text = json.dumps(report, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            write_text(Path(args.output), text)
        else:
            sys.stdout.write(text)
        return 0 if report.get("status") == "pass" else 1

    if not args.input:
        parser.error("input Plan42 JSON file is required unless --ouroboros or --list-targets is used")

    return compile_plan42(
        Path(args.input),
        Path(args.output) if args.output else None,
        target=args.target,
        include_runtime=args.runtime,
        diagnostics_path=Path(args.diagnostics) if args.diagnostics else None,
        compatibility_path=Path(args.compatibility) if args.compatibility else None,
        fail_on_incompatible=args.fail_on_incompatible,
    )


if __name__ == "__main__":
    raise SystemExit(main())
