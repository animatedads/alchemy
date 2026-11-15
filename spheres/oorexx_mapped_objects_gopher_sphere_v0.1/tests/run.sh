#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tests/validate_sphere.py" "$ROOT"
: "$GOPHER"
"$GOPHER" --profile mapped-objects context mapped-objects --full | grep -q '"mapped-objects.start"'
echo "PASS mapped-objects SPHERE v0.1 structural + context"
