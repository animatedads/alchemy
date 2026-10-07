#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((50000 + RANDOM % 1000))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add NATIVEPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" --filters zero-block,crunch >/dev/null
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/socket_provider${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
PAYLOAD='native-selector-roundtrip-0000000000000000'

# Native Rexx listener retains one libxtp Listener object while the ordinary
# libxtp client transmits a filtered XTP transaction into it.
"$REXX_BIN" "$ROOT/tests/test_socket_selector_xtp_native.rex" NATIVEPEER listener "$PAYLOAD" >"$TMP/listener.out" 2>"$TMP/listener.err" &
lpid=$!
sleep .2
"$ROOT/bin/xtp-connect" NATIVEPEER --message "$PAYLOAD" >"$TMP/client.out" 2>"$TMP/client.err"
wait "$lpid" || { cat "$TMP/listener.out"; cat "$TMP/listener.err" >&2; exit 1; }
cat "$TMP/listener.out"
grep -q '^PASS native listener bytes=' "$TMP/listener.out"

# Native Rexx sender uses the same in-process binding; no shell connector.
"$ROOT/bin/xtp-listen" NATIVEPEER --max 1 >"$TMP/server.out" 2>"$TMP/server.err" &
spid=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_socket_selector_xtp_native.rex" NATIVEPEER sender "$PAYLOAD" >"$TMP/sender.out" 2>"$TMP/sender.err"
wait "$spid" || { cat "$TMP/server.out"; cat "$TMP/server.err" >&2; exit 1; }
cat "$TMP/sender.out"
grep -q '^PASS native sender bytes=' "$TMP/sender.out"
grep -q 'XTP_ACCEPT .*bytes=' "$TMP/server.out"
echo 'PASS native ooRexx SocketSelector sender/listener -> libxtp'
