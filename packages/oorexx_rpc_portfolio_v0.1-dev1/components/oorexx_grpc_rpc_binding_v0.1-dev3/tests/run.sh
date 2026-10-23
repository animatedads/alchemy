#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${OOREXX_RUNTIME_ROOT:?set OOREXX_RUNTIME_ROOT to extracted ooRexx package root}"
: "${RPC_CORE_ROOT:?set RPC_CORE_ROOT to RPC Service Core root}"
: "${SERIALIZATION_ROOT:?set SERIALIZATION_ROOT to Serialisation Selector root}"
export REXX_PATH="$HERE/src:$RPC_CORE_ROOT/src:$SERIALIZATION_ROOT/src:$OOREXX_RUNTIME_ROOT/usr/local/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OOREXX_RUNTIME_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_grpc.rex"
if [ -n "${CONNECT_SELECTOR_ROOT:-}" ]; then
  export REXX_PATH="$CONNECT_SELECTOR_ROOT/src:$REXX_PATH"
  "$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_connect.rex"
fi
