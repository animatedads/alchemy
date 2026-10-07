#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
TMP="$(mktemp -d "$ROOT/tests/tmp_terminal_socket.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
GOOD="$(printf '44%.0s' {1..64})"
BAD="$(printf '55%.0s' {1..64})"
assertions=0
wait_port() {
  local pf="$1" pid="$2"
  for _ in $(seq 1 200); do
    [[ -s "$pf" ]] && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 0.02
  done
  return 1
}

# 1. One mutually authenticated connection carries multiple broker requests.
PF="$TMP/valid.port"; SF="$TMP/valid.status"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_server.rex "$PF" "$SF" "$GOOD") >"$TMP/valid.server.out" 2>"$TMP/valid.server.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/valid.server.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
client_out="$(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_client.rex "$port" "$GOOD" VALID)"
[[ "$client_out" == *"VALID_OK authenticated=AI_A;body_claim=AI_EVIL_BODY_CLAIM;requests=2;state=DISCONNECTED"* ]]; ((assertions+=1))
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"serve_ok=1"* && "$status" == *"connections=1"* && "$status" == *"authenticated=1"* && "$status" == *"rejected=0"* && "$status" == *"requests=2"* && "$status" == *"endpoint_calls=2"* && "$status" == *"last_principal=AI_A"* && "$status" == *"endpoint_closed=0"* && "$status" == *"state=STOPPED"* ]]; ((assertions+=4))

# 2. Wrong HMAC key never authenticates and never reaches the endpoint.
PF="$TMP/wrong.port"; SF="$TMP/wrong.status"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_server.rex "$PF" "$SF" "$GOOD") >"$TMP/wrong.server.out" 2>"$TMP/wrong.server.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/wrong.server.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
wrong_out="$(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_client.rex "$port" "$BAD" REJECT)"
[[ "$wrong_out" == *"AUTH_REJECTED"* ]]; ((assertions+=1))
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"serve_ok=0"* && "$status" == *"authenticated=0"* && "$status" == *"rejected=1"* && "$status" == *"requests=0"* && "$status" == *"endpoint_calls=0"* ]]; ((assertions+=3))

# 3. A valid handshake followed by a forged request MAC is rejected before
# endpoint dispatch.  Authentication is per-request, not just per connection.
PF="$TMP/tamper.port"; SF="$TMP/tamper.status"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_server.rex "$PF" "$SF" "$GOOD") >"$TMP/tamper.server.out" 2>"$TMP/tamper.server.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/tamper.server.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
tamper_out="$(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_tamper_client.rex "$port" "$GOOD")"
[[ "$tamper_out" == *"TAMPER_REJECTED"* ]]; ((assertions+=1))
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"serve_ok=0"* && "$status" == *"authenticated=1"* && "$status" == *"rejected=1"* && "$status" == *"requests=0"* && "$status" == *"endpoint_calls=0"* ]]; ((assertions+=3))

# 4. A fake local server cannot authenticate itself with a forged challenge.
PF="$TMP/fake-challenge.port"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_fake_server.rex "$PF" "$GOOD" BAD_CHALLENGE) >"$TMP/fake-challenge.server.out" 2>"$TMP/fake-challenge.server.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/fake-challenge.server.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
fake_challenge_out="$(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_client.rex "$port" "$GOOD" SERVER_REJECT)"
[[ "$fake_challenge_out" == *"SERVER_AUTH_REJECTED code=BROKER_SOCKET_SERVER_AUTH_FAILED"* ]]; ((assertions+=1))
wait "$pid"

# 5. A protocol-shaped response with a forged MAC is rejected by the client.
PF="$TMP/fake-response.port"
(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_fake_server.rex "$PF" "$GOOD" BAD_RESPONSE) >"$TMP/fake-response.server.out" 2>"$TMP/fake-response.server.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/fake-response.server.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
fake_response_out="$(cd "$ROOT" && "$REXX" tests/terminal_broker_socket_client.rex "$port" "$GOOD" RESPONSE_REJECT)"
[[ "$fake_response_out" == *"RESPONSE_REJECTED code=BROKER_SOCKET_RESPONSE_AUTH_FAILED"* ]]; ((assertions+=1))
wait "$pid"

echo "TERMINAL BROKER LOCAL SOCKET: OK"
echo "assertions=$assertions"
