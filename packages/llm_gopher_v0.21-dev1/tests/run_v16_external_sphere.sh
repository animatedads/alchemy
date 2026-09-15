#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${LLM_GOPHER_TEST_PITFALLS_SPHERE:?set LLM_GOPHER_TEST_PITFALLS_SPHERE}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LLM_GOPHER_ENV="$TMP/env"

"$ROOT/gopher" sphere load oorexx-llm-pitfalls --override "$LLM_GOPHER_TEST_PITFALLS_SPHERE" > "$TMP/load"
grep -q '"class": "ACTIVATED"' "$TMP/load"
grep -q '"sphere": "oorexx-llm-pitfalls"' "$TMP/load"

"$ROOT/gopher" --profile oorexx-llm-pitfalls context oorexx-llm-pitfalls --full > "$TMP/context"
grep -q '"class": "OPENED"' "$TMP/context"
grep -q '"oorexx"' "$TMP/context"
grep -q '"source.oorexx.examine"' "$TMP/context"
grep -q 'ops.oorexx-llm-pitfalls.overview' "$TMP/context"

echo "PASS ALL LLM GOPHER v0.16 EXTERNAL SPHERE COMPOSITION TESTS"
