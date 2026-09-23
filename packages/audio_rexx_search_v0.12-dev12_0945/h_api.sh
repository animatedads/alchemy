#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${1:-health}; PAYLOAD=${2:--}
URL=${ED209H_API_URL:-https://ed209h-api:9443}
CA=${ED209H_API_CA:-$ROOT/control/ed209h-ca.pem}
TOKEN=${ED209H_API_TOKEN_FILE:-$ROOT/control/ed209h-api.token}
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
export REXX_PATH="$ROOT/vendor/api_client_v0.3:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$OOREXX_PREFIX/bin/rexx" "$ROOT/bin/AudioHApiFeeder.rex" "$MODE" "$URL" "$CA" "$TOKEN" "$PAYLOAD" "$ROOT/vendor/api_client_v0.3/bridge"
