#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'kill ${LPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
cat > "$XTP_ROUTE_FILE" <<ROUTES
#peer	layer	carrier	destination	interface	metric	enabled	wire_filters	multicast
RX	4	udp	127.0.0.1:29876		10	1		0
ROUTES
"$ROOT/bin/xtp-listen" RX --count 1 --timeout-ms 3000 --exchange-route 0x12345678 --hex >"$TMP/listener.out" 2>"$TMP/listener.err" &
LPID=$!
for _ in $(seq 1 50); do
  grep -q 'XTP_LISTEN_READY' "$TMP/listener.out" 2>/dev/null && break
  sleep 0.02
done
grep -q 'XTP_LISTEN_READY' "$TMP/listener.out"
"$ROOT/bin/xtp-connect" RX --hex 010203040506 --key 36020 --timeout-ms 500 --retries 4 --route-value 0x01020304 >"$TMP/client.out"
wait "$LPID"
grep -q 'route=16909060' "$TMP/client.out"
grep -q 'return_route=2164392708' "$TMP/client.out"
grep -q 'xroute=305419896' "$TMP/client.out"
grep -q 'route=16909060' "$TMP/listener.out"
grep -q 'data=010203040506' "$TMP/listener.out"
echo 'PASS XTP ROUTE/XROUTE endpoint exchange and return-form route'
