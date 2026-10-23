#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tests/validate_sphere.py" "$ROOT"
: "$GOPHER"
CTX=$(mktemp)
SEARCH=$(mktemp)
trap 'rm -f "$CTX" "$SEARCH"' 0 1 2 3 15
"$GOPHER" --profile nosqlserver context nosqlserver --full > "$CTX"
grep -q '"nosqlserver.start"' "$CTX"
grep -q '"nosqlserver.sqlite-writable-v091"' "$CTX"
"$GOPHER" --profile nosqlserver search sqlite --sphere nosqlserver > "$SEARCH"
grep -q '"class": "FOUND"' "$SEARCH"
echo "PASS nosqlserver SPHERE v0.3 structural + search"
