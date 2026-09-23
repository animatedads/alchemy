#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "$ROOT/tests/tmp_socket_health.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
KEY="$(printf '33%.0s' {1..64})"
PORTFILE="$TMP/port"
STATUSFILE="$TMP/status"
export REXX_PATH="$ROOT/src:/usr/local/bin${REXX_PATH:+:$REXX_PATH}"
(
  cd "$ROOT"
  rexx tests/socket_server.rex "$TMP/b" "$PORTFILE" "$STATUSFILE" "$KEY" 10 2
) >"$TMP/server.out" 2>"$TMP/server.err" &
SERVER_PID=$!
for _ in $(seq 1 100); do
  [[ -s "$PORTFILE" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server.err" >&2; exit 1; }
  sleep 0.05
done
[[ -s "$PORTFILE" ]] || { echo "listener port not published" >&2; exit 1; }
LIVEPORT="$(tr -d '\r\n' < "$PORTFILE")"
DEADPORT="$(cd "$ROOT" && rexx tests/socket_unused_port.rex | tr -d '\r\n')"
[[ "$DEADPORT" != "$LIVEPORT" ]] || DEADPORT="$(cd "$ROOT" && rexx tests/socket_unused_port.rex | tr -d '\r\n')"
(
  cd "$ROOT"
  rexx tests/socket_failover_client.rex "$TMP/a" "$LIVEPORT" "$DEADPORT" "$KEY"
)
wait "$SERVER_PID"
STATUS="$(cat "$STATUSFILE")"
[[ "$STATUS" == *"connections=2;authenticated=2;accepted=2;rejected=0;ipRejected=0;probes=1"* ]]
echo "OBJECT QUEUE FABRIC V0.9-dev6 ENCRYPTED HEALTH/FAILOVER: OK"
echo "assertions=15"
