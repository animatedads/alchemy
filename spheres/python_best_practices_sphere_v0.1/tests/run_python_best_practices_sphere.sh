#!/bin/sh
# Qualification for the Python Best Practices Gopher sphere v0.1.
# Data-only: no ooRexx runtime and no source archive required.
# Run from a LLM Gopher distribution root with packs/core present and this
# sphere's packs/python-best-practices + profiles/python-best-practices.json installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LLM_GOPHER_ENV="${LLM_GOPHER_ENV:-$TMP/gopher-env}"

"$ROOT/gopher" --profile python-best-practices context python-best-practices > "$TMP/context.json"
grep -q '"sphere": "python-best-practices"' "$TMP/context.json"
grep -q 'python-best-practices.defaults.no-mutable-default-argument' "$TMP/context.json"
grep -q 'python-best-practices.optional.truthiness-not-none' "$TMP/context.json"
grep -q 'python-best-practices.edits.preserve-unrelated-bytes' "$TMP/context.json"

"$ROOT/gopher" --profile python-best-practices open python-best-practices.defaults.no-mutable-default-argument > "$TMP/open.json"
grep -q 'mutable default' "$TMP/open.json"

"$ROOT/gopher" --profile python-best-practices search 'mutable default' --sphere python-best-practices > "$TMP/search.json"
grep -q '"class": "FOUND"' "$TMP/search.json"
grep -q 'mutable-default' "$TMP/search.json"

"$ROOT/gopher" --profile python-best-practices lookup topic=none-check --sphere python-best-practices > "$TMP/lookup.json"
grep -q 'EXACT_FIELD' "$TMP/lookup.json"
grep -q 'is None' "$TMP/lookup.json"

# Reference rule documents are shown via rules show (not executed by rules check).
"$ROOT/gopher" --profile python-best-practices rules show PYTHON.DEFAULT_MUTABLE --language python > "$TMP/r_default.json"
grep -q '"id": "PYTHON.DEFAULT_MUTABLE"' "$TMP/r_default.json"
"$ROOT/gopher" --profile python-best-practices rules show PYTHON.CONDITION_EQ_TRUE --language python > "$TMP/r_eq.json"
grep -q '"id": "PYTHON.CONDITION_EQ_TRUE"' "$TMP/r_eq.json"

# Example splices must parse as a single method each and contain no mutable default literal.
for f in "$ROOT"/examples/python-method/*.py.frag; do
  python3 - "$f" <<'PY'
import ast, json, sys
src = open(sys.argv[1], encoding="utf-8").read()
tree = ast.parse("class __Splice__:\n" + "\n".join("    " + ln for ln in src.splitlines() if ln.strip() or True))
body = tree.body[0].body
assert len(body) == 1 and isinstance(body[0], (ast.FunctionDef, ast.AsyncFunctionDef)), sys.argv[1]
defaults = []
defs = body[0].args.defaults + [d for g in body[0].args.kw_defaults if g is not None]
for d in defs:
    if isinstance(d, (ast.List, ast.Set, ast.Dict)):
        defaults.append(ast.dump(d))
assert not defaults, (sys.argv[1], defaults)
PY
done

"$ROOT/gopher" --profile python-best-practices help python-best-practices > "$TMP/help.json"
grep -q 'python-best-practices' "$TMP/help.json"

echo 'PASS ALL Python Best Practices Gopher sphere v0.1 TESTS'
