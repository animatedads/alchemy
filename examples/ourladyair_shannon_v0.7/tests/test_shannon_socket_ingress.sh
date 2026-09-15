#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?pass Shannon root}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
KEY="$(printf '66%.0s' {1..64})"
PORTFILE="$TMP/port"
STATUSFILE="$TMP/status"

"$ROOT/run_rexx.sh" "$ROOT/tests/socket_shannon_server.rex" "$ROOT" "$PORTFILE" "$STATUSFILE" "$KEY" >"$TMP/server.out" 2>"$TMP/server.err" &
SERVER_PID=$!
for _ in $(seq 1 160); do
  [[ -s "$PORTFILE" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server.err" >&2; exit 1; }
  sleep 0.05
done
[[ -s "$PORTFILE" ]] || { echo 'Shannon socket listener did not publish a port' >&2; kill "$SERVER_PID" 2>/dev/null || true; exit 1; }
PORT="$(tr -d '\r\n' < "$PORTFILE")"
"$ROOT/run_rexx.sh" "$ROOT/tests/socket_shannon_client.rex" 127.0.0.1 "$PORT" "$KEY" >"$TMP/client.out" 2>"$TMP/client.err"
wait "$SERVER_PID"
STATUS="$(cat "$STATUSFILE")"
[[ "$STATUS" == *'serve=OK'* ]]
[[ "$STATUS" == *'mode=TRANSPORT_TEST'* ]]
[[ "$STATUS" == *'audit=ourladyair.shannon.turn.v3'* ]]
[[ "$STATUS" == *'fabric='* ]]
[[ "$STATUS" == *'indexed=1'* ]]
[[ "$STATUS" == *'SOCKET_ECHO:Can I put my EpiPen'* ]]
echo 'PASS test_shannon_socket_ingress'
echo "$STATUS"
