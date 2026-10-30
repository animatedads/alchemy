#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
SOCKET_PROVIDER_SRC="${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must point to the current Socket Provider source (dev16 authority)}"
RXSOCK_SRC="${RXSOCK_SRC:?RXSOCK_SRC must point to directory containing socket.cls}"

command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "FAIL: $REXX_BIN not found"; exit 20; }

REXX_PATH_NEW="$ROOT/src:$SOCKET_PROVIDER_SRC:$RXSOCK_SRC"
if [[ -n "${CRYPTO_SRC:-}" || -n "${CRYPTO_AUTH_SRC:-}" ]]; then
  [[ -n "${CRYPTO_SRC:-}" && -n "${CRYPTO_AUTH_SRC:-}" ]] || {
    echo "FAIL: CRYPTO_SRC and CRYPTO_AUTH_SRC must be supplied together"; exit 21;
  }
  REXX_PATH_NEW="$REXX_PATH_NEW:$CRYPTO_SRC:$CRYPTO_AUTH_SRC"
fi
export REXX_PATH="$REXX_PATH_NEW${REXX_PATH:+:$REXX_PATH}"

"$REXX_BIN" -v || true
"$REXX_BIN" "$ROOT/tests/test_websocket_contract.rex"
"$REXX_BIN" "$ROOT/tests/test_server_access.rex"

if [[ -n "${CRYPTO_SRC:-}" ]]; then
  "$REXX_BIN" "$ROOT/tests/test_platform_crypto.rex"
else
  echo "SKIP WebSocket estate crypto adapter contract (CRYPTO_SRC/CRYPTO_AUTH_SRC not supplied)"
fi

python3 "$ROOT/tests/live_echo_server.py" >"$ROOT/tests/live_server.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 50); do
  grep -q READY "$ROOT/tests/live_server.log" 2>/dev/null && break
  sleep 0.1
done
grep -q READY "$ROOT/tests/live_server.log" || { cat "$ROOT/tests/live_server.log"; exit 30; }
"$REXX_BIN" "$ROOT/tests/test_live_cots_client.rex"
echo "PASS WebSocket environment qualification"
