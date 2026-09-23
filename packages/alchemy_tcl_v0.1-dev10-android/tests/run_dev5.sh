#!/data/data/com.termux/files/usr/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}
REXX=${REXX:-"$OOREXX_BUILD/bin/rexx"}
"$ROOT/tests/build_native.sh"
export LD_LIBRARY_PATH="$ROOT/build:$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT/tests"
echo "== dev3 resident/re-entry =="
"$REXX" ./test_roundtrip.rex
echo "== dev4 retained identity =="
"$REXX" ./test_retained_identity.rex
echo "== dev5 retained identity through Tcl =="
"$REXX" ./test_dev5_tcl_retained.rex
