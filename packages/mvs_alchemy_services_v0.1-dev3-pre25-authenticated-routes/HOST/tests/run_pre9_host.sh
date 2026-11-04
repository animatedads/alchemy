#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REXX=${REXX:-rexx}
REXXC=${REXXC:-rexxc}
PORT=${MAS_TEST_PORT:-37076}
STATE=${MAS_TEST_STATE:-/tmp/mas-pre9-host-test}
LOG=${MAS_TEST_LOG:-$STATE/gateway-log.txt}
rm -rf "$STATE"; mkdir -p "$STATE"
$REXXC "$ROOT/HOST/src/MasWire.cls" >/dev/null
$REXXC "$ROOT/HOST/src/MasLiveGateway.cls" >/dev/null
$REXXC "$ROOT/HOST/bin/mas-live-gateway.rex" >/dev/null
($REXX "$ROOT/HOST/bin/mas-live-gateway.rex" "$PORT" "$STATE" "$LOG" > "$STATE/stdout" 2>&1) &
pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
for _ in $(seq 1 40); do
  ss -ltn 2>/dev/null | grep -Eq "127\\.0\\.0\\.1:$PORT[[:space:]]" && break
  sleep .1
done
python3 "$ROOT/HOST/tests/live_gateway_reference_client.py" 127.0.0.1 "$PORT"
wait "$pid"
grep -q 'phase=COMMIT.*operation=5157' "$LOG"
grep -q 'phase=COMMIT.*operation=5377' "$LOG"
echo 'PASS PRE9_HOST_GATEWAY'
