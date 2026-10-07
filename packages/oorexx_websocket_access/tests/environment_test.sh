#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
SOCKET_PROVIDER_SRC="${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must point to Socket Provider dev10 src}"
RXSOCK_SRC="${RXSOCK_SRC:?RXSOCK_SRC must point to directory containing socket.cls}"
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo "FAIL: $REXX_BIN not found"; exit 20; }
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_SRC:$RXSOCK_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" -v || true
"$REXX_BIN" "$ROOT/tests/test_websocket_contract.rex"
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
