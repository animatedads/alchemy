#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${REXX_BIN:=rexx}"
: "${SOCKET_PROVIDER_ROOT:?set SOCKET_PROVIDER_ROOT to current SocketProvider source/classes}"
: "${EVENT_RUNTIME_ROOT:?set EVENT_RUNTIME_ROOT to oorexx_event_runtime_v0.1-dev1}"
: "${NORM_ROOT:?set NORM_ROOT to oorexx_norm source package}"
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_ROOT/src:$EVENT_RUNTIME_ROOT/src:$NORM_ROOT/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$NORM_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/tests/live_norm_multi_membership.rex" "${NORM_INTERFACE:-lo}"
