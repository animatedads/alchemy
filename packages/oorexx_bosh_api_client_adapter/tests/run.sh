#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${BOSH_ROOT:?BOSH_ROOT must point to oorexx_bosh_transport source root}"
: "${API_CLIENT_ROOT:?API_CLIENT_ROOT must point to oorexx_api_client_v0.4.1 source root}"
REXX=${REXX:-rexx}
export REXX_PATH="$ROOT/src:$BOSH_ROOT/src:$API_CLIENT_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_bosh_api_client_adapter.rex"
