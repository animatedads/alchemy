#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXX_BIN:=rexx}"
: "${EVENT_RUNTIME_ROOT:?set EVENT_RUNTIME_ROOT to oorexx_event_runtime_v0.1-dev1}"
export REXX_PATH="$ROOT/src:$EVENT_RUNTIME_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_adapter.rex"
"$REXX_BIN" "$ROOT/tests/test_multi_descriptor.rex"
