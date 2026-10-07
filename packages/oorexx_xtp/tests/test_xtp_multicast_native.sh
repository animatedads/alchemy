#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
command -v "$REXX_BIN" >/dev/null 2>&1 || { echo 'SKIP native Rexx multicast (rexx unavailable)'; exit 0; }
[[ -f "$ROOT/lib/liboorexx_xtp_native.so" ]] || { echo 'SKIP native Rexx multicast (native library unavailable)'; exit 0; }
TMP=$(mktemp -d)
trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv" XTP_HEALTH_FILE="$TMP/health.tsv"
"$ROOT/bin/xtp-admin" route add MCG --layer 4 --carrier udp --to 239.192.0.37:29361 --multicast >/dev/null
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/socket_provider${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" "$ROOT/tests/test_xtp_multicast_native_listener.rex" >"$TMP/listen.out" 2>"$TMP/listen.err" & LPID=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_xtp_multicast_native_sender.rex" >"$TMP/send.out" 2>"$TMP/send.err"
wait "$LPID"; LPID=
grep -q 'PASS native Rexx XTP multicast sender' "$TMP/send.out"
grep -q 'PASS native Rexx XTP multicast listener' "$TMP/listen.out"
echo 'PASS SocketSelector-shaped ooRexx backend -> native libxtp multicast'
