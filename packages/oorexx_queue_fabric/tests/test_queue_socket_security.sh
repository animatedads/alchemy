#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "$ROOT/tests/tmp_socket_security.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
GOOD="$(printf '44%.0s' {1..64})"
BAD="$(printf '55%.0s' {1..64})"
export REXX_PATH="$ROOT/src:/usr/local/bin${REXX_PATH:+:$REXX_PATH}"
assertions=0
wait_port() {
  local pf="$1" pid="$2"
  for _ in $(seq 1 120); do
    [[ -s "$pf" ]] && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 0.05
  done
  return 1
}

# 1. Wrong client key: server must never insert or receipt the package.
PF="$TMP/wrong.port"; SF="$TMP/wrong.status"
(cd "$ROOT" && rexx tests/socket_server.rex "$TMP/wrong-b" "$PF" "$SF" "$GOOD" 10 1 0) >"$TMP/wrong.out" 2>"$TMP/wrong.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/wrong.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && rexx tests/socket_client.rex "$TMP/wrong-a" "$port" "$BAD" ANY)
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"authenticated=0"* && "$status" == *"depth=0"* && "$status" == *"receipts=0"* ]]; ((assertions+=2))

# 2. Same transfer over two fresh TCP connections is receiver-idempotent.
PF="$TMP/replay.port"; SF="$TMP/replay.status"
(cd "$ROOT" && rexx tests/socket_server.rex "$TMP/replay-b" "$PF" "$SF" "$GOOD" 10 2 0) >"$TMP/replay.out" 2>"$TMP/replay.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/replay.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
replay="$(cd "$ROOT" && rexx tests/socket_replay_client.rex "$port" "$GOOD")"
[[ "$replay" == *"second=duplicate"* ]]; ((assertions+=1))
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"connections=2;authenticated=2;accepted=2;rejected=0"* && "$status" == *"depth=1;receipts=1"* ]]; ((assertions+=2))

# 3. Queue-full is an authenticated application rejection; source work is released.
PF="$TMP/full.port"; SF="$TMP/full.status"
(cd "$ROOT" && rexx tests/socket_server.rex "$TMP/full-b" "$PF" "$SF" "$GOOD" 1 1 1) >"$TMP/full.out" 2>"$TMP/full.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/full.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && rexx tests/socket_client.rex "$TMP/full-a" "$port" "$GOOD" QUEUE_FULL)
((assertions+=2)) # client script checks READY release, deliveryCount=1, backoutCount=0
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"authenticated=1;accepted=1;rejected=0"* && "$status" == *"depth=1;receipts=0"* ]]; ((assertions+=1))

# 4. A protocol-shaped fake RESULT with a forged MAC is rejected by A.
PF="$TMP/fake.port"
(cd "$ROOT" && rexx tests/socket_fake_server.rex "$PF" "$GOOD") >"$TMP/fake.out" 2>"$TMP/fake.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/fake.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && rexx tests/socket_client.rex "$TMP/fake-a" "$port" "$GOOD" SECURE_AUTHENTICATION_FAILED)
wait "$pid"
((assertions+=1))

# 5. Correct cryptographic key from the wrong source IP is rejected before HELLO/authentication.
PF="$TMP/ip.port"; SF="$TMP/ip.status"
(cd "$ROOT" && rexx tests/socket_server.rex "$TMP/ip-b" "$PF" "$SF" "$GOOD" 10 1 0 127.0.0.2) >"$TMP/ip.out" 2>"$TMP/ip.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/ip.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && rexx tests/socket_client.rex "$TMP/ip-a" "$port" "$GOOD" ANY) >"$TMP/ip-client.out" 2>"$TMP/ip-client.err"
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"authenticated=0"* && "$status" == *"ipRejected=1"* ]]; ((assertions+=1))
[[ "$status" == *"depth=0;receipts=0"* ]]; ((assertions+=1))

# 6. Re-registering the same peer with a new IP removes its old address from pre-auth admission.
PF="$TMP/retrust.port"; SF="$TMP/retrust.status"
(cd "$ROOT" && rexx tests/socket_server.rex "$TMP/retrust-b" "$PF" "$SF" "$GOOD" 10 1 0 127.0.0.2 127.0.0.1) >"$TMP/retrust.out" 2>"$TMP/retrust.err" & pid=$!
wait_port "$PF" "$pid" || { cat "$TMP/retrust.err" >&2; exit 1; }
port="$(tr -d '\r\n' < "$PF")"
(cd "$ROOT" && rexx tests/socket_client.rex "$TMP/retrust-a" "$port" "$GOOD" ANY) >"$TMP/retrust-client.out" 2>"$TMP/retrust-client.err"
wait "$pid"
status="$(cat "$SF")"
[[ "$status" == *"authenticated=0"* && "$status" == *"ipRejected=1"* ]]; ((assertions+=1))
[[ "$status" == *"depth=0;receipts=0"* ]]; ((assertions+=1))

echo "OBJECT QUEUE FABRIC V0.9-dev6 SOCKET SECURITY: OK assertions=$assertions"
