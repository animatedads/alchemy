#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SSC_ROOT:?set SSC_ROOT to oorexx_semantic_source_control_v0.2.3 or compatible}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/scan.txt"
"$SSC_ROOT/bin/osc" scan "$ROOT" --repo "$TMP/repo" --component WireUIBuilder >"$OUT"
grep -q '^SCAN COMPLETE$' "$OUT"
expected="$(find "$ROOT" -type f | wc -l | tr -d ' ')"
actual="$(sed -n 's/^files= *\([0-9][0-9]*\).*/\1/p' "$OUT")"
methods="$(sed -n 's/.*methods= *\([0-9][0-9]*\).*/\1/p' "$OUT")"
attributes="$(sed -n 's/.*attributes= *\([0-9][0-9]*\).*/\1/p' "$OUT")"
constants="$(sed -n 's/.*constants= *\([0-9][0-9]*\).*/\1/p' "$OUT")"
[[ "$actual" == "$expected" ]]
[[ "$methods" -ge 180 ]]
[[ "$attributes" -ge 120 ]]
[[ "$constants" -ge 2 ]]
echo "PASS test_semantic_source_control releaseFiles=$actual methods=$methods attributes=$attributes constants=$constants"
