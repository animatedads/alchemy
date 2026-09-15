#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX=${REXX:-rexx}
: "${API_CLIENT_HOME:?set API_CLIENT_HOME to extracted oorexx_api_client_v0.3 package root}"
: "${FOREIGN_RUNTIME_HOME:?set FOREIGN_RUNTIME_HOME to extracted oorexx_foreign_runtime_v0.22.5}"
: "${ALLOCATOR_HOME:?set ALLOCATOR_HOME to extracted job_node_allocator_v0.6}"
: "${CRYPTO_HOME:?set CRYPTO_HOME to extracted oorexx_crypto_v0.8.3}"
OLD_REXX_PATH=${REXX_PATH:-}
export REXX_PATH="$ROOT/src:$API_CLIENT_HOME/src:$FOREIGN_RUNTIME_HOME/rexx:$ALLOCATOR_HOME/src:$CRYPTO_HOME/src${OO_REXX_BIN:+:$OO_REXX_BIN}${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
export LD_LIBRARY_PATH="${OO_REXX_LIB:-}${OO_REXX_LIB:+:}$FOREIGN_RUNTIME_HOME/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
chmod 600 "$ROOT/tests/huggingface.key"
chmod 644 "$ROOT/tests/bad.key"
rm -rf "$ROOT/tests/output"; mkdir -p "$ROOT/tests/output"
(cd "$ROOT/tests" && "$REXX" test_core.rex)
(cd "$ROOT/tests" && "$REXX" test_allocator.rex)
(cd "$ROOT/tests" && "$REXX" test_discovery.rex)
(cd "$ROOT/tests" && "$REXX" test_receipts.rex)
python3 "$ROOT/tests/tls/server.py" >"$ROOT/tests/tls/server.log" 2>&1 &
pid=$!
trap 'kill "$pid" >/dev/null 2>&1 || true' EXIT INT TERM
sleep 1
(cd "$ROOT/src" && "$REXX" ../tests/test_https_end_to_end.rex "$API_CLIENT_HOME/bridge" ../tests/tls/cert.pem)
(cd "$ROOT/src" && "$REXX" ../tests/test_https_auto_v1_fallback.rex "$API_CLIENT_HOME/bridge" ../tests/tls/cert.pem)
kill "$pid" >/dev/null 2>&1 || true
trap - EXIT INT TERM
