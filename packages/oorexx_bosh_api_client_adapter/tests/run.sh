#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${BOSH_ROOT:?BOSH_ROOT must point to oorexx_bosh_transport source root}"
: "${API_CLIENT_ROOT:?API_CLIENT_ROOT must point to oorexx_api_client_v0.4.1 source root}"
REXX=${REXX:-rexx}
REXXC=${REXXC:-rexxc}

command -v "$REXX" >/dev/null 2>&1 || { echo "FAIL ooRexx interpreter not found: $REXX" >&2; exit 2; }
command -v "$REXXC" >/dev/null 2>&1 || { echo "FAIL ooRexx compiler not found: $REXXC" >&2; exit 2; }
test -f "$BOSH_ROOT/src/BoshTransport.cls" || { echo "FAIL BoshTransport.cls missing from $BOSH_ROOT/src" >&2; exit 2; }
test -f "$API_CLIENT_ROOT/src/ApiClient.cls" || { echo "FAIL ApiClient.cls missing from $API_CLIENT_ROOT/src" >&2; exit 2; }

export REXX_PATH="$ROOT/src:$BOSH_ROOT/src:$API_CLIENT_ROOT/src${REXX_PATH:+:$REXX_PATH}"

"$REXX" -v
"$REXXC" "$ROOT/src/BoshApiClientAdapter.cls"
"$REXX" "$ROOT/tests/test_bosh_api_client_adapter.rex"
