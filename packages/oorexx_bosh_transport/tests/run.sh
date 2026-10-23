#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX=${REXX:-rexx}
if [ -z "${INSTRUMENTATION_MESH_ROOT:-}" ]; then
  echo "INSTRUMENTATION_MESH_ROOT is required for dev5 qualification" >&2
  exit 2
fi
export REXX_PATH="$ROOT/src:$INSTRUMENTATION_MESH_ROOT/src${SOCKET_PROVIDER_ROOT:+:$SOCKET_PROVIDER_ROOT/src}${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_bosh_transport.rex"
"$REXX" "$ROOT/tests/test_bosh_stream_semantics.rex"
"$REXX" "$ROOT/tests/test_bosh_upper_binding_seam.rex"
"$REXX" "$ROOT/tests/test_bosh_instrumentation_mesh.rex"
if [ -n "${SOCKET_PROVIDER_ROOT:-}" ]; then
  "$REXX" "$ROOT/tests/test_bosh_socket_provider_adapter.rex"
fi
