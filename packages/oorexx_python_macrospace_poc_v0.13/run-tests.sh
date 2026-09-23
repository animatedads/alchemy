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

for demo in object_demo.py reversal_demo.py mixed_collection_demo.py unknown_demo.py arguments_return_object_demo.py profile_demo.py guarded_start_demo.py stem_demo.py demo.py; do
    echo "== $demo =="
    "$PYTHON" "$ROOT/python/$demo"
done

echo "== numeric_codec.py policy =="
python tests/test_numeric_codec.py
echo "== numeric_torture_demo.py =="
python python/numeric_torture_demo.py
echo "== numeric_context_demo.py =="
python python/numeric_context_demo.py
echo "== argument_semantics_demo.py =="
python python/argument_semantics_demo.py
echo "ALL v0.13 POC TESTS PASS"
