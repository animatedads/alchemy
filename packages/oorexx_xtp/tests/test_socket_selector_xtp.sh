#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((48000 + RANDOM % 1000))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add SOCKETPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" --filters zero-block,crunch >/dev/null
"$ROOT/bin/xtp-local" server --carrier udp --bind "127.0.0.1:$PORT" --max 1 >"$TMP/server.out" 2>"$TMP/server.err" &
spid=$!
sleep 0.15
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/socket_provider${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$REXX_BIN" "$ROOT/tests/test_socket_selector_xtp.rex" SOCKETPEER "$ROOT/bin/xtp-connect"
wait "$spid"
grep -q 'DELIVER carrier=udp' "$TMP/server.out"
echo 'PASS real ooRexx SocketSelector -> XTP provider -> libxtp -> UDP'
