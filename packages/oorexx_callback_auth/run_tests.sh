#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${CRYPTO_SRC:?Set CRYPTO_SRC to oorexx_crypto_v0.8.3/src}"
: "${CRYPTO_AUTH_SRC:?Set CRYPTO_AUTH_SRC to oorexx_crypto_auth_v0.1-dev1/src}"
: "${API_CLIENT_SRC:?Set API_CLIENT_SRC to oorexx_api_client_v0.4.1/src}"
export REXX_PATH="$ROOT/src:$CRYPTO_AUTH_SRC:$CRYPTO_SRC:$API_CLIENT_SRC:${REXX_PATH:-}"
for t in "$ROOT"/tests/test_*.rex; do
  echo "== $(basename "$t") =="
  rexx "$t"
done
