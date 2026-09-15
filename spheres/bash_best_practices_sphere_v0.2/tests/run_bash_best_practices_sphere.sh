#!/bin/sh
# Qualification for the Bash Best Practices Gopher sphere v0.2.
# Data-only: no ooRexx runtime and no source archive required.
# Run from a LLM Gopher distribution root with packs/core present and this
# sphere's packs/bash-best-practices + profiles/bash-best-practices.json installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LLM_GOPHER_ENV="${LLM_GOPHER_ENV:-$TMP/gopher-env}"

"$ROOT/gopher" --profile bash-best-practices context bash-best-practices > "$TMP/context.json"
grep -q '"sphere": "bash-best-practices"' "$TMP/context.json"
grep -q 'bash-best-practices.exec.sourced-lib-vs-executed-tool' "$TMP/context.json"
grep -q 'bash-best-practices.data.output-is-data-never-executed' "$TMP/context.json"
grep -q 'bash-best-practices.evidence.evidence-is-not-acceptance' "$TMP/context.json"
grep -q 'bash-best-practices.json.emit-and-protect' "$TMP/context.json"
grep -q 'ops.rule-classification' "$TMP/context.json"

"$ROOT/gopher" --profile bash-best-practices open bash-best-practices.data.output-is-data-never-executed > "$TMP/open.json"
grep -q 'provider or helper is data, never shell' "$TMP/open.json"

"$ROOT/gopher" --profile bash-best-practices search 'self-authored' --sphere bash-best-practices > "$TMP/search.json"
grep -q '"class": "FOUND"' "$TMP/search.json"
grep -q 'self-authored acceptance' "$TMP/search.json"

"$ROOT/gopher" --profile bash-best-practices lookup topic=json-emit --sphere bash-best-practices > "$TMP/lookup.json"
grep -q 'EXACT_FIELD' "$TMP/lookup.json"
grep -q 'backslash' "$TMP/lookup.json"

# Reference bash rules are shown via rules show (no built-in bash evaluator).
# Regression guard: quoting is contextual, never a blanket AUTOMATIC.
"$ROOT/gopher" --profile bash-best-practices rules show BASH.QUOTING.UNQUOTED_EXPANSION --language bash > "$TMP/r_quote.json"
grep -q '"id": "BASH.QUOTING.UNQUOTED_EXPANSION"' "$TMP/r_quote.json"
grep -q '"fixability": "MANUAL"' "$TMP/r_quote.json"
grep -q 'unsafe_without_intent' "$TMP/r_quote.json"
"$ROOT/gopher" --profile bash-best-practices rules show BASH.SAFETY.EVAL_SOURCE_INDIRECT --language bash > "$TMP/r_eval.json"
grep -q '"id": "BASH.SAFETY.EVAL_SOURCE_INDIRECT"' "$TMP/r_eval.json"
"$ROOT/gopher" --profile bash-best-practices rules show BASH.JSON.RAW_STRING_CONCAT --language bash > "$TMP/r_json.json"
grep -q '"id": "BASH.JSON.RAW_STRING_CONCAT"' "$TMP/r_json.json"

"$ROOT/gopher" --profile bash-best-practices help bash-best-practices > "$TMP/help.json"
grep -q 'bash-best-practices' "$TMP/help.json"

echo 'PASS ALL Bash Best Practices Gopher sphere v0.2 TESTS'
