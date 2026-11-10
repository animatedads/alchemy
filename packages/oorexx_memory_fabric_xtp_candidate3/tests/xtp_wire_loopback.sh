#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${XTP_DIR:?Provide XTP source root}"
: "${SERVICE_DESCRIPTORS_DIR:?Provide Service Descriptors source root}"
: "${SOCKET_PROVIDER_DIR:?Provide Socket Provider source root}"
: "${REXX_BIN:=rexx}"
TEMP=$(mktemp -d)
L_PID=''
trap 'if [[ -n "$L_PID" ]]; then kill "$L_PID" 2>/dev/null || true; fi; rm -rf "$TEMP"' EXIT
export XTP_ROUTE_FILE="$TEMP/routes.tsv"
export XTP_HEALTH_FILE="$TEMP/health.tsv"
export MF_TEST_REGISTRY="$TEMP/services.tsv"
export REXX_PATH="$ROOT/src:$SERVICE_DESCRIPTORS_DIR/rexx:$SOCKET_PROVIDER_DIR/src:$XTP_DIR/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$XTP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$XTP_DIR/bin/xtp-admin" route add mem-mu5 --layer 4 --carrier udp --to 127.0.0.1:44997 >"$TEMP/routes.log"
"$XTP_DIR/bin/xtp-listen" mem-mu5 --allow-services memory.block.read --timeout-ms 4000 >"$TEMP/listener.log" 2>"$TEMP/listener.err" &
L_PID=$!
for i in $(seq 1 80); do
 if grep -q XTP_LISTEN_READY "$TEMP/listener.log" 2>/dev/null; then break; fi
 sleep 0.03
done
"$REXX_BIN" "$ROOT/tests/test_xtp_named_service_wire.rex" >"$TEMP/client.log" 2>&1 || { cat "$TEMP/client.log"; cat "$TEMP/listener.err"; exit 1; }
wait "$L_PID"
L_PID=''
grep -q 'service=memory.block.read' "$TEMP/listener.log"
grep -q 'data=MF-CONTROL-FIRST' "$TEMP/listener.log"
cat "$TEMP/client.log"
echo 'PASS FIRST service name and control bytes over real XTP/UDP loopback'
