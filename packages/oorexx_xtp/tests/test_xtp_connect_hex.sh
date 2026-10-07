#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((47000 + RANDOM % 1000))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add TESTHEX --layer 4 --carrier udp --to "127.0.0.1:$PORT" --filters zero-block,crunch >/dev/null
"$ROOT/bin/xtp-local" server --carrier udp --bind "127.0.0.1:$PORT" --max 1 >"$TMP/server.out" 2>"$TMP/server.err" &
spid=$!
sleep 0.15
"$ROOT/bin/xtp-connect" TESTHEX --hex 00010200ff >"$TMP/client.out"
wait "$spid"
grep -q 'XTP_CONNECT_OK' "$TMP/client.out"
grep -q 'data=' "$TMP/server.out"
echo 'PASS xtp-connect binary --hex through libxtp'
