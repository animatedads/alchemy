#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${FB_EXTERNAL_CASH_DOMAIN:?set FB_EXTERNAL_CASH_DOMAIN to federationbank_external_cash_v0.1 root}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to Queue Fabric src}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to Alchemy Objects src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to ooRexx Crypto src}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$FB_EXTERNAL_CASH_DOMAIN/src:$QUEUE_FABRIC_SRC:$ALCHEMY_SRC:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
for t in "$HERE"/tests/test_*.rex; do echo "== $(basename "$t") =="; "$REXX_BIN" "$t"; done
