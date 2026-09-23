#!/data/data/com.termux/files/usr/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}
REXX=${REXX:-"$OOREXX_BUILD/bin/rexx"}
chmod +x "$ROOT/tests/build_native.sh" "$ROOT/tests/run_roundtrip.sh" "$ROOT/tests/run_dev4.sh" "$ROOT/tests/run_dev5.sh" "$ROOT/tests/run_dev6.sh" 2>/dev/null || true
"$ROOT/tests/build_native.sh"
export LD_LIBRARY_PATH="$ROOT/build:$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT/tests"
"$REXX" ./test_roundtrip.rex
"$REXX" ./test_retained_identity.rex
"$REXX" ./test_dev5_tcl_retained.rex
echo "== dev6 persistent projection / Tcl rename-delete =="
"$REXX" ./test_dev6_projection.rex
