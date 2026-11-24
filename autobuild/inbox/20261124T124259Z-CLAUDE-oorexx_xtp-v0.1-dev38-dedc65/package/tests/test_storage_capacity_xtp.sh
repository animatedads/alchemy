#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:?REXX_BIN required}"
: "${OP_PLANNER_ROOT:?OP_PLANNER_ROOT required}"
: "${SERVICE_DESCRIPTOR_ROOT:?SERVICE_DESCRIPTOR_ROOT required}"
: "${STORAGE_ROOT:?STORAGE_ROOT required}"
: "${SOCKET_PROVIDER_DIR:?SOCKET_PROVIDER_DIR required}"
TMP=$(mktemp -d); trap 'kill ${LPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv" XTP_HEALTH_FILE="$TMP/health.tsv"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$ROOT/rexx:$SOCKET_PROVIDER_DIR:$OP_PLANNER_ROOT/rexx:$SERVICE_DESCRIPTOR_ROOT/rexx:$STORAGE_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$ROOT/bin/xtp-admin" route add storage-pressure-peer --layer 4 --carrier udp --to 127.0.0.1:44923 >/dev/null
"$REXX_BIN" "$ROOT/tests/test_storage_capacity_xtp_listener.rex" storage-pressure-peer >"$TMP/listener" 2>"$TMP/listener.err" & LPID=$!
for _ in $(seq 1 100); do grep -q READY "$TMP/listener" 2>/dev/null && break; sleep .01; done
"$REXX_BIN" "$ROOT/tests/test_storage_capacity_xtp_sender.rex" storage-pressure-peer "$OP_PLANNER_ROOT" "$SERVICE_DESCRIPTOR_ROOT" >"$TMP/sender" 2>"$TMP/sender.err"
wait "$LPID"; LPID=
grep -q 'PASS Storage ticket -> XTP named service' "$TMP/sender"
grep -q 'PASS listener two transactions' "$TMP/listener"
cat "$TMP/sender"
echo 'PASS cross-layer Storage capacity ticket -> ooRexx XTP named-service live pacing'
