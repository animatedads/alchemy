#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "$ROOT/tests/tmp_socket_transport.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
KEY="$(printf '22%.0s' {1..64})"
PORTFILE="$TMP/port"
STATUSFILE="$TMP/status"
export REXX_PATH="$ROOT/src:/usr/local/bin${REXX_PATH:+:$REXX_PATH}"
(
  cd "$ROOT"
  rexx tests/socket_server.rex "$TMP/b" "$PORTFILE" "$STATUSFILE" "$KEY" 10 1
) >"$TMP/server.out" 2>"$TMP/server.err" &
SERVER_PID=$!
for _ in $(seq 1 100); do
  [[ -s "$PORTFILE" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server.err" >&2; exit 1; }
  sleep 0.05
done
[[ -s "$PORTFILE" ]] || { echo "listener port not published" >&2; exit 1; }
PORT="$(tr -d '\r\n' < "$PORTFILE")"
(
  cd "$ROOT"
  rexx tests/socket_client.rex "$TMP/a" "$PORT" "$KEY"
)
wait "$SERVER_PID"
RECOVERY="$(cd "$ROOT" && rexx tests/socket_recover.rex "$TMP/b")"
[[ "$RECOVERY" == *"depth=1;receipts=1;kind=render;step2=encode;correlation=socket-42"* ]]
STATUS="$(cat "$STATUSFILE")"
[[ "$STATUS" == *"connections=1;authenticated=1;accepted=1;rejected=0"* ]]
echo "OBJECT QUEUE FABRIC V0.9-dev5 ENCRYPTED SOCKET TRANSPORT: OK"
echo "assertions=6"
