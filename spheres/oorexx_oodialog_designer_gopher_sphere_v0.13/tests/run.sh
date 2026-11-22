#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$ROOT/tests/validate_sphere.py" "$ROOT"
: "$GOPHER"
"$GOPHER" --profile oodialog-designer context oodialog-designer --full | grep -q '"oodialog-designer.start"'
echo "PASS oodialog-designer SPHERE v0.1 structural + context"
