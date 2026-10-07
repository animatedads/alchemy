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
echo "== cross_boundary_argument_semantics_demo.py =="
python python/cross_boundary_argument_semantics_demo.py
echo "ALL v0.14 POC TESTS PASS"

echo "== rexx_to_python_argument_semantics_demo.py =="
python "$ROOT/python/rexx_to_python_argument_semantics_demo.py"

echo "== existing_unknown_collision_demo.py =="
python "$ROOT/python/existing_unknown_collision_demo.py"

echo "== guarded_unguarded_concurrency_demo.py =="
python "$ROOT/python/guarded_unguarded_concurrency_demo.py"

echo "== python_inheritance_demo.py =="
python "$ROOT/python/python_inheritance_demo.py"

echo "== rexx_proxy_inheritance_demo.py =="
python "$ROOT/python/rexx_proxy_inheritance_demo.py"


if [ -n "${ALCHEMY_OBJECTS_SRC:-}" ]; then
  echo "== alchemy_python_adoption_probe.rex =="
  REXX_PATH="$ROOT/rexx:$ALCHEMY_OBJECTS_SRC${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/rexx/alchemy_python_adoption_probe.rex"
else
  echo "== Alchemy adoption probe SKIP (set ALCHEMY_OBJECTS_SRC to authoritative Alchemy Objects src) =="
fi

# Current bridge qualification: keep every ownership/live-surgery regression in
# the aggregate harness so a green run cannot silently omit a newer torture.
for torture in \
  python_object_lifetime_torture.py \
  python_class_handle_lifetime_torture.py \
  returned_proxy_lifetime_torture.py \
  rexx_held_proxy_lifetime_torture.py \
  registry_rollback_torture.py \
  python_type_authority_torture.py \
  live_dual_method_surgery.py \
  rexx_callable_live_surgery.py \
  concurrent_dual_runtime_surgery.py
do
  echo "== $torture =="
  "$PYTHON" "$ROOT/python/$torture"
done

echo "ALL CURRENT OWNERSHIP / LIVE-SURGERY TORTURES PASS"
