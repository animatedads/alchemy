#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

: "${OOREXX_ROOT:?OOREXX_ROOT is required}"
: "${SOCKET_PROVIDER_ROOT:?SOCKET_PROVIDER_ROOT must contain the exact Socket Provider source used for qualification}"
: "${INSTRUMENTATION_MESH_ROOT:?INSTRUMENTATION_MESH_ROOT must contain the exact Instrumentation Mesh source used for qualification}"

REXX=${REXX:-$OOREXX_ROOT/bin/rexx}
REXXC=${REXXC:-$OOREXX_ROOT/bin/rexxc}

test -x "$REXX" || { echo "FAIL ooRexx interpreter not found: $REXX" >&2; exit 2; }
test -x "$REXXC" || { echo "FAIL ooRexx compiler not found: $REXXC" >&2; exit 2; }
test -f "$SOCKET_PROVIDER_ROOT/src/SocketProvider.cls" || { echo "FAIL SocketProvider.cls not found under $SOCKET_PROVIDER_ROOT/src" >&2; exit 2; }
test -f "$INSTRUMENTATION_MESH_ROOT/src/InstrumentationMesh.cls" || { echo "FAIL InstrumentationMesh.cls not found under $INSTRUMENTATION_MESH_ROOT/src" >&2; exit 2; }
test -f "$INSTRUMENTATION_MESH_ROOT/src/InstrumentationServiceAdapters.cls" || { echo "FAIL InstrumentationServiceAdapters.cls not found under $INSTRUMENTATION_MESH_ROOT/src" >&2; exit 2; }
test -f "$INSTRUMENTATION_MESH_ROOT/src/InstrumentationCorrelation.cls" || { echo "FAIL InstrumentationCorrelation.cls not found under $INSTRUMENTATION_MESH_ROOT/src" >&2; exit 2; }

export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_ROOT/src:$INSTRUMENTATION_MESH_ROOT/src${REXX_PATH:+:$REXX_PATH}"

"$REXXC" "$ROOT/src/BoshTransport.cls"
"$REXXC" "$ROOT/src/BoshSocketProviderAdapter.cls"
"$REXXC" "$ROOT/src/BoshInstrumentationAdapter.cls"

REXX="$REXX" \
SOCKET_PROVIDER_ROOT="$SOCKET_PROVIDER_ROOT" \
INSTRUMENTATION_MESH_ROOT="$INSTRUMENTATION_MESH_ROOT" \
"$ROOT/tests/run.sh"

echo "PASS BOSH dev6 environment qualification"
