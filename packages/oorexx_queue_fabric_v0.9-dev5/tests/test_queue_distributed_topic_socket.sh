#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "$ROOT/tests/tmp_distributed_topic_socket.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
KEY="$(printf '66%.0s' {1..64})"
PORTFILE="$TMP/port"
STATUSFILE="$TMP/status"
export REXX_PATH="$ROOT/src:/usr/lib/ooRexx${REXX_PATH:+:$REXX_PATH}"
(
  cd "$ROOT"
  rexx tests/distributed_topic_socket_server.rex "$TMP/b" "$PORTFILE" "$STATUSFILE" "$KEY"
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
  rexx tests/distributed_topic_socket_client.rex "$PORT" "$KEY"
)
wait "$SERVER_PID"
STATUS="$(cat "$STATUSFILE")"
[[ "$STATUS" == *"depth=1;receipts=1;order=808;step2=deliver;path=QM.A>QM.B"* ]]
RECOVERY="$(cd "$ROOT" && rexx tests/distributed_topic_socket_recover.rex "$TMP/b")"
[[ "$RECOVERY" == *"depth=1;receipts=1;order=808;step2=deliver"* ]]
echo "OBJECT QUEUE FABRIC V0.9-dev5 ENCRYPTED DISTRIBUTED TOPIC SOCKET: OK"
echo "assertions=6"
