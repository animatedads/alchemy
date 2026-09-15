#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
TMP="$(mktemp -d "$ROOT/tests/tmp_terminal_ops_service.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
KEY="$(printf '77%.0s' {1..64})"
PF="$TMP/service.port"; SF="$TMP/service.status"
(cd "$ROOT" && "$REXX" tests/terminal_broker_operations_service_server.rex "$PF" "$SF" "$KEY") >"$TMP/server.out" 2>"$TMP/server.err" & spid=$!
for _ in $(seq 1 300); do
  [[ -s "$PF" ]] && break
  kill -0 "$spid" 2>/dev/null || { cat "$TMP/server.err" >&2; exit 1; }
  sleep 0.02
done
[[ -s "$PF" ]] || { echo "operations service port not published" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_service_client.rex "$port" AI_A "$KEY" 0.80) >"$TMP/a.out" 2>"$TMP/a.err" & apid=$!
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_service_client.rex "$port" AI_B "$KEY" 0.80) >"$TMP/b.out" 2>"$TMP/b.err" & bpid=$!
wait "$apid"
wait "$bpid"
wait "$spid"
grep -q 'SERVICE_AUTH_CLIENT_OK AI_A' "$TMP/a.out"
grep -q 'SERVICE_AUTH_CLIENT_OK AI_B' "$TMP/b.out"
status="$(cat "$SF")"
[[ "$status" == *"health=QUIESCED"* ]]
[[ "$status" == *"lifecycle=QUIESCED"* ]]
[[ "$status" == *"socket=DRAINED"* ]]
[[ "$status" == *"listener=STOPPED"* ]]
[[ "$status" == *"generation=1"* ]]
[[ "$status" == *"connections=2"* ]]
[[ "$status" == *"active=0"* ]]
[[ "$status" == *"peak=2"* ]]
[[ "$status" == *"completed=2"* ]]
[[ "$status" == *"authenticated=2"* ]]
[[ "$status" == *"rejected=2"* ]]
[[ "$status" == *"requests=0"* ]]
[[ "$status" == *"protocol=QUIESCED"* ]]
[[ "$status" == *"broker=OPEN"* ]]
[[ "$status" == *"broker_close=0"* ]]
[[ "$status" == *"endpoint_calls=0"* ]]
echo "TERMINAL BROKER OPERATIONAL SUPERVISOR SERVICE: OK"
echo "$status"
