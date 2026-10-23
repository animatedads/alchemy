#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${OOREXX_ROOT:=/usr/local}"
: "${SOCKET_PROVIDER_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_socket_provider_v0.1-dev10}"
: "${SOCKET_TELEMETRY_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_socket_isolation_telemetry_v0.1-dev2}"
: "${INSTRUMENTATION_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_instrumentation_mesh_v0.1-dev7}"
make -C "$ROOT" clean all OOREXX_ROOT="$OOREXX_ROOT"
export LD_LIBRARY_PATH="$ROOT/build:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_ROOT/src:$SOCKET_TELEMETRY_ROOT/src:$INSTRUMENTATION_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/shared_rtp_probe.rex"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/instrumentation_probe.rex"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/socket_telemetry_rtp_probe.rex"
echo "PASS RTP dev6 environment qualification"