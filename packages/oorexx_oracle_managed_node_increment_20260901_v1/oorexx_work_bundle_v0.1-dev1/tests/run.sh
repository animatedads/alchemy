#!/usr/bin/env bash
set -euo pipefail
REXX=${REXX:-/usr/local/bin/rexx}
CRYPTO_SRC=${CRYPTO_SRC:?set CRYPTO_SRC to Crypto src directory}
export REXX_PATH="$(cd "$(dirname "$0")/../src" && pwd):$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$(dirname "$0")"
"$REXX" test_bundle.rex
"$REXX" test_ed25519_proof.rex
