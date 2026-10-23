#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PY=${LLM_GOPHER_PYTHON:-python3}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PDF="$ROOT/tests/fixtures/reference_manual.pdf"
HTML="$ROOT/tests/fixtures/reference_manual.html"
test -f "$PDF"
test -f "$HTML"

"$ROOT/gopher" reference find $PDF "USE STRICT ARG" > "$TMP/find-pdf"
grep -q '"class": "FOUND"' "$TMP/find-pdf"
grep -q '"physical_page": 4' "$TMP/find-pdf"

"$ROOT/gopher" reference locate $PDF --reference-page 2 --approx-page 4 --window 2 > "$TMP/locate"
grep -q '"physical_page": 4' "$TMP/locate"

"$ROOT/gopher" reference read $PDF --page 4 --reference-page 2 > "$TMP/read"
grep -q '"class": "OPENED"' "$TMP/read"
grep -q '"reference_page_hint": 2' "$TMP/read"
grep -q '"next": 5' "$TMP/read"
grep -q 'USE STRICT ARG' "$TMP/read"

"$ROOT/gopher" reference move $PDF --page 4 1 > "$TMP/move-next"
grep -q '"physical_page": 5' "$TMP/move-next"
"$ROOT/gopher" reference move $PDF --page 4 -1 > "$TMP/move-prev"
grep -q '"physical_page": 3' "$TMP/move-prev"

"$ROOT/gopher" reference find $HTML "Diagnostic" > "$TMP/find-html"
grep -q '"class": "FOUND"' "$TMP/find-html"
grep -q '"section": 1' "$TMP/find-html"

# Capability schemas remain discoverable.
"$ROOT/gopher" describe reference.document.find --sphere core > "$TMP/describe"
grep -q '"reference.document.find"' "$TMP/describe"
grep -q '"bounded-search"' "$TMP/describe"

# The LLM-facing manual-navigation sphere explains how to use the reader.
"$ROOT/gopher" --profile manual-navigation context manual-navigation --full > "$TMP/manual-context"
grep -q '"manual-navigation.start"' "$TMP/manual-context"
grep -q '"manual-navigation.printed-vs-physical"' "$TMP/manual-context"
"$ROOT/gopher" --profile manual-navigation search 'reference find' --sphere manual-navigation > "$TMP/manual-search"
grep -q '"class": "FOUND"' "$TMP/manual-search"
"$ROOT/gopher" reference -h > "$TMP/help"
grep -q 'find/locate -> read -> move' "$TMP/help"
grep -q 'rexxref.pdf' "$TMP/help"

echo "PASS ALL LLM GOPHER v0.21 REFERENCE READER TESTS"
