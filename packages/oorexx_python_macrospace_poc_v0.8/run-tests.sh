#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"

# Keep a source-tree ooRexx build visible at runtime on Termux/Android.
OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}
if [ -d "$OOREXX_LIB" ]; then
    export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
export PYTHONPATH="$ROOT/python${PYTHONPATH:+:$PYTHONPATH}"
PYTHON=${PYTHON:-python3}

for demo in object_demo.py reversal_demo.py mixed_collection_demo.py unknown_demo.py arguments_return_object_demo.py demo.py; do
    echo "== $demo =="
    "$PYTHON" "$ROOT/python/$demo"
done

echo "ALL v0.8 POC TESTS PASS"
