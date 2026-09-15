#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
MATHS_ZIP=${MATHS_ZIP:-/mnt/data/oorexx_maths_v0.7.zip}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

"$ROOT/gopher" --profile maths context maths > "$TMP/context.json"
grep -q '"sphere": "maths"' "$TMP/context.json"
grep -q 'maths.current' "$TMP/context.json"
grep -q 'maths.continuity' "$TMP/context.json"
grep -q 'source.oorexx.examine' "$TMP/context.json"

"$ROOT/gopher" --profile maths open maths.current > "$TMP/current.json"
grep -q 'oorexx_maths_v0.7.zip' "$TMP/current.json"
grep -q 'b2385efc83aa525392f6c804327f7d370abd6c06d04a7d31855803e62f95c19d' "$TMP/current.json"

"$ROOT/gopher" --profile maths search '50 digits' --sphere maths > "$TMP/precision.json"
grep -q '"class": "FOUND"' "$TMP/precision.json"
grep -q 'Binary64 is opt-in' "$TMP/precision.json"

"$ROOT/gopher" --profile maths search quadratic --sphere maths > "$TMP/quadratic.json"
grep -q '"class": "FOUND"' "$TMP/quadratic.json"
grep -q 'polynomials/quadratics' "$TMP/quadratic.json"

"$ROOT/gopher" --profile maths help maths > "$TMP/help.json"
grep -q 'maths.current' "$TMP/help.json"
grep -q 'source.oorexx.examine' "$TMP/help.json"

if [ -f "$MATHS_ZIP" ]; then
  "$ROOT/gopher" --profile maths examine source Maths.cls --in "$MATHS_ZIP" --symbol MathQuantizationScheme --sphere maths > "$TMP/source.json"
  grep -q '"class": "EXAMINED"' "$TMP/source.json"
  grep -q 'MathQuantizationScheme' "$TMP/source.json"
  grep -q 'class_count' "$TMP/source.json"
fi

echo 'PASS ALL ooRexx Maths Gopher sphere v0.1 TESTS'
