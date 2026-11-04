#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${MEMORY_FABRIC_DIR:?}" "${SERVICE_DESCRIPTORS_DIR:?}" "${XTP_DIR:?}" "${OPERATIONAL_PLANNER_DIR:?}" "${SOCKET_PROVIDER_DIR:?}"
: "${REXX_BIN:=rexx}"
TEMP=$(mktemp -d); LPID=''
trap 'if [[ -n "$LPID" ]]; then kill "$LPID" 2>/dev/null || true; fi; rm -rf "$TEMP"' EXIT
export XTP_ROUTE_FILE="$TEMP/routes.tsv" XTP_HEALTH_FILE="$TEMP/health.tsv"
export MF_TEST_REGISTRY="$TEMP/services.tsv" OPERATIONAL_POLICY_FILE="$TEMP/class.tsv" OPERATIONAL_CAPACITY_FILE="$TEMP/cap.tsv"
export MF_OPCTL="$OPERATIONAL_PLANNER_DIR/bin/opctl"
export REXX_PATH="$ROOT/src:$MEMORY_FABRIC_DIR/src:$SERVICE_DESCRIPTORS_DIR/rexx:$XTP_DIR/rexx:$SOCKET_PROVIDER_DIR/src:$OPERATIONAL_PLANNER_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$XTP_DIR/lib:${LD_LIBRARY_PATH:-}"
"$MF_OPCTL" class add normal.memory --normal allow:100:allow:any:30:2:60 --degraded throttle:75:allow:any:25:2:50 --constrained throttle:50:forbid:protected:15:1:15 --emergency suspend:0:forbid:protected:10:1:10 >/dev/null
"$XTP_DIR/bin/xtp-admin" route add mem-mu5 --layer 4 --carrier udp --to 127.0.0.1:45267 >/dev/null
"$REXX_BIN" "$ROOT/tests/test_memory_xtp_admission_wire_listener.rex" mem-mu5 >"$TEMP/listener.log" 2>"$TEMP/listener.err" & LPID=$!
for n in $(seq 1 100); do grep -q 'READY' "$TEMP/listener.log" 2>/dev/null && break; sleep 0.025; done
"$REXX_BIN" "$ROOT/tests/test_memory_xtp_admission_wire_sender.rex" >"$TEMP/sender.log" 2>"$TEMP/sender.err" || { cat "$TEMP/sender.log" "$TEMP/sender.err" "$TEMP/listener.err"; exit 1; }
wait "$LPID"; LPID=''
grep -q 'PASS Memory XTP listener two' "$TEMP/listener.log"
grep -q 'PASS Memory XTP live named service capacity' "$TEMP/sender.log"
cat "$TEMP/sender.log" "$TEMP/listener.log"
