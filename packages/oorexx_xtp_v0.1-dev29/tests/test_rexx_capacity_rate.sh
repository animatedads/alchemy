#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:?REXX_BIN required}"
TMP=$(mktemp -d); trap 'kill ${LPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv" XTP_HEALTH_FILE="$TMP/health.tsv"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$ROOT/bin/xtp-admin" route add rexx-rate-node --layer 4 --carrier udp --to 127.0.0.1:44920 >/dev/null
"$REXX_BIN" "$ROOT/tests/test_rexx_capacity_rate_listener.rex" rexx-rate-node >"$TMP/listener" & LPID=$!
for _ in $(seq 1 100); do grep -q READY "$TMP/listener" 2>/dev/null && break; sleep .01; done
start=$(date +%s%N)
"$REXX_BIN" "$ROOT/tests/test_rexx_capacity_rate_sender.rex" rexx-rate-node >"$TMP/sender"
end=$(date +%s%N)
wait "$LPID"
ms=$(( (end-start)/1000000 ))
grep -q 'PASS sender' "$TMP/sender"; grep -q 'PASS listener' "$TMP/listener"
if (( ms < 185 || ms > 2500 )); then echo "FAIL ooRexx rate elapsed_ms=$ms"; exit 1; fi
echo "PASS ooRexx named-service capacity rate elapsed_ms=$ms"
