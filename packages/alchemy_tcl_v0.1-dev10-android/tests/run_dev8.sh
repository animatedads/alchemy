#!/data/data/com.termux/files/usr/bin/sh
set -eu
R=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
B=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}; L=${OOREXX_LIB:-"$B/lib"}; X=${REXX:-"$B/bin/rexx"}
chmod +x "$R"/tests/*.sh 2>/dev/null || true
"$R/tests/build_native.sh"
export LD_LIBRARY_PATH="$R/build:$L${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$R/tests"
"$X" test_roundtrip.rex
"$X" test_retained_identity.rex
"$X" test_dev5_tcl_retained.rex
"$X" test_dev6_projection.rex
"$X" test_dev7_lifecycle.rex
echo "== dev8 structured Tcl completion/error evidence =="
"$X" test_dev8_errors.rex
