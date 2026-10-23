#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
LPID=
cleanup(){ set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add RX --layer 4 --carrier udp --to 127.0.0.1:29609 --metric 10 --filters zero-block,crunch >/dev/null
"$ROOT/bin/xtp-listen" RX --count 2 --hex >"$TMP/listen.out" 2>"$TMP/listen.err" & LPID=$!
sleep .08
PAYLOAD=00000000414141414141414100ff
"$ROOT/bin/xtp-connect" RX --hex "$PAYLOAD" --key 9101 >"$TMP/c1.out" 2>"$TMP/c1.err"
"$ROOT/bin/xtp-connect" RX --hex "$PAYLOAD" --key 9101 >"$TMP/c2.out" 2>"$TMP/c2.err"
"$ROOT/bin/xtp-connect" RX --hex 42494e41525900ff --key 9102 >"$TMP/c3.out" 2>"$TMP/c3.err"
wait "$LPID"; LPID=
grep -q '^XTP_LISTEN_READY peer=RX layer=4 carrier=udp' "$TMP/listen.out"
[[ $(grep -c '^XTP_ACCEPT key=9101 ' "$TMP/listen.out") -eq 1 ]]
[[ $(grep -c '^XTP_ACCEPT key=9102 ' "$TMP/listen.out") -eq 1 ]]
grep -q "data=$PAYLOAD" "$TMP/listen.out"
grep -q 'XTP_REPLAY_SUPPRESSED key=9101' "$TMP/listen.err"
grep -q 'XTP_CONNECT_OK peer=RX layer=4 carrier=udp' "$TMP/c1.out"
grep -q 'XTP_CONNECT_OK peer=RX layer=4 carrier=udp' "$TMP/c2.out"
grep -q 'XTP_CONNECT_OK peer=RX layer=4 carrier=udp' "$TMP/c3.out"
echo 'PASS libxtp persistent Listener receives filtered binary payloads and suppresses duplicate KEY delivery'
