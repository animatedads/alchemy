#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OOREXX_HOME="${OOREXX_HOME:-/usr/local}"
WIRE_UI_SERVER_HOME="${WIRE_UI_SERVER_HOME:-}"
CRYPTO_HOME="${CRYPTO_HOME:-}"
RUNTIME_REFERENCE_HOME="${RUNTIME_REFERENCE_HOME:-}"
FOREIGN_RUNTIME_HOME="${FOREIGN_RUNTIME_HOME:-}"
REXX_BIN="${REXX_BIN:-$OOREXX_HOME/bin/rexx}"
[[ -x "$REXX_BIN" ]] || { echo "FAIL rexx not found: $REXX_BIN" >&2; exit 2; }
[[ -f "$WIRE_UI_SERVER_HOME/src/WireUIProtocol.cls" ]] || { echo 'FAIL WIRE_UI_SERVER_HOME' >&2; exit 2; }
[[ -f "$CRYPTO_HOME/src/crypto.cls" ]] || { echo 'FAIL CRYPTO_HOME' >&2; exit 2; }
[[ -f "$RUNTIME_REFERENCE_HOME/src/RuntimeImplementationReference.cls" ]] || { echo 'FAIL RUNTIME_REFERENCE_HOME' >&2; exit 2; }
[[ -f "$FOREIGN_RUNTIME_HOME/rexx/foreign.cls" ]] || { echo 'FAIL FOREIGN_RUNTIME_HOME' >&2; exit 2; }
export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib:$FOREIGN_RUNTIME_HOME/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$WIRE_UI_SERVER_HOME/src:$CRYPTO_HOME/src:$RUNTIME_REFERENCE_HOME/src:$FOREIGN_RUNTIME_HOME/rexx:$OOREXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export QEB_CRYPTO_ACCEL=1
export REXX_BIN
cd "$ROOT/tests"
"$REXX_BIN" test_ed25519_kat.rex
"$REXX_BIN" test_broker_core.rex
"$REXX_BIN" test_jsonl_restart.rex
./test_local_authorizer.sh
