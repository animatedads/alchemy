#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_ROOT:?OOREXX_ROOT is required}"
: "${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC is required for adapter qualification}"
REXX=${REXX:-$OOREXX_ROOT/bin/rexx}
REXXC=${REXXC:-$OOREXX_ROOT/bin/rexxc}
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXXC" "$ROOT/src/BoshTransport.cls"
"$REXXC" "$ROOT/src/BoshSocketProviderAdapter.cls"
"$REXX" "$ROOT/tests/test_bosh_transport.rex"
"$REXX" "$ROOT/tests/test_bosh_stream_semantics.rex"
"$REXX" "$ROOT/tests/test_bosh_telemetry.rex"
"$REXX" "$ROOT/tests/test_bosh_socket_provider_adapter.rex"
echo "PASS BOSH dev2 environment qualification"
