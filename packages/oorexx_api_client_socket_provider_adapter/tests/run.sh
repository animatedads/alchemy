#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${API_CLIENT_ROOT:?API_CLIENT_ROOT must point to oorexx_api_client_v0.4.1}"
: "${SOCKET_PROVIDER_ROOT:?SOCKET_PROVIDER_ROOT must point to oorexx_socket_provider}"
REXX=${REXX:-rexx}
REXXC=${REXXC:-rexxc}

command -v "$REXX" >/dev/null 2>&1 || { echo "FAIL ooRexx interpreter not found: $REXX" >&2; exit 2; }
command -v "$REXXC" >/dev/null 2>&1 || { echo "FAIL ooRexx compiler not found: $REXXC" >&2; exit 2; }
test -f "$API_CLIENT_ROOT/src/ApiHttpTransport.cls" || { echo "FAIL ApiHttpTransport.cls missing" >&2; exit 2; }
test -f "$SOCKET_PROVIDER_ROOT/src/SocketProvider.cls" || { echo "FAIL SocketProvider.cls missing" >&2; exit 2; }
test -f "$SOCKET_PROVIDER_ROOT/src/SocketIntentions.cls" || { echo "FAIL SocketIntentions.cls missing" >&2; exit 2; }

export REXX_PATH="$ROOT/src:$API_CLIENT_ROOT/src:$SOCKET_PROVIDER_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" -v
"$REXXC" "$API_CLIENT_ROOT/src/ApiHttpTransport.cls"
"$REXXC" "$ROOT/src/ApiClientSocketProviderAdapter.cls"
"$REXX" "$ROOT/tests/test_socket_provider_carrier.rex"
"$REXX" "$ROOT/tests/test_socket_intention_route_resolver.rex"
