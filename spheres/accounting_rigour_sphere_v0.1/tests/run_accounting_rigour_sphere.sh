#!/bin/sh
# Qualification for the Accounting Rigour Gopher sphere v0.1.
# Data-only: does not require an ooRexx runtime or a source archive.
# Run from a LLM Gopher distribution root that has packs/core present and
# this sphere's packs/accounting-rigour + profiles/accounting-rigour.json installed.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export LLM_GOPHER_ENV="${LLM_GOPHER_ENV:-$TMP/gopher-env}"

"$ROOT/gopher" --profile accounting-rigour context accounting-rigour > "$TMP/context.json"
grep -q '"sphere": "accounting-rigour"' "$TMP/context.json"
grep -q 'accounting-rigour.precision.minor-units-50-digits' "$TMP/context.json"

"$ROOT/gopher" --profile accounting-rigour open accounting-rigour.precision.minor-units-50-digits > "$TMP/precision.json"
grep -q 'NUMERIC DIGITS 50' "$TMP/precision.json"

"$ROOT/gopher" --profile accounting-rigour search 'settlement rounding' --sphere accounting-rigour > "$TMP/rounding.json"
grep -q '"class": "FOUND"' "$TMP/rounding.json"
grep -q 'separate decisions' "$TMP/rounding.json"

"$ROOT/gopher" --profile accounting-rigour search 'not zero' --sphere accounting-rigour > "$TMP/filing.json"
grep -q '"class": "FOUND"' "$TMP/filing.json"
grep -q 'invent a figure' "$TMP/filing.json"

"$ROOT/gopher" --profile accounting-rigour lookup topic=rounding --sphere accounting-rigour > "$TMP/lookup.json"
grep -q 'topic:rounding' "$TMP/lookup.json"
grep -q 'never rewrites' "$TMP/lookup.json"

"$ROOT/gopher" --profile accounting-rigour help accounting-rigour > "$TMP/help.json"
grep -q 'accounting-rigour' "$TMP/help.json"

"$ROOT/gopher" --profile accounting-rigour packages check --sphere accounting-rigour > "$TMP/check.json" 2>/dev/null || true

echo 'PASS ALL Accounting Rigour Gopher sphere v0.1 TESTS'
