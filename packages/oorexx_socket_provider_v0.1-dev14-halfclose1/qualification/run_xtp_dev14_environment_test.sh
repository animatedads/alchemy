#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
: "${XTP_DEV14_ROOT:?XTP_DEV14_ROOT must point to extracted oorexx_xtp_v0.1-dev14}"

[[ -f "$XTP_DEV14_ROOT/rexx/XtpSocketProvider.cls" ]] || { echo 'FAIL: XTP dev14 source tree not found'; exit 20; }
[[ -x "$XTP_DEV14_ROOT/bin/xtp-admin" ]] || { echo 'FAIL: XTP dev14 executables not built'; exit 21; }
[[ -f "$XTP_DEV14_ROOT/lib/liboorexx_xtp_native.so" ]] || { echo 'FAIL: liboorexx_xtp_native.so not built'; exit 22; }

TMP="$(mktemp -d)"
trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((54000 + RANDOM % 500))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$XTP_DEV14_ROOT/bin/xtp-admin" route add MERGEDPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" --filters zero-block,crunch >/dev/null
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$XTP_DEV14_ROOT/lib:${LD_LIBRARY_PATH:-}"
PAYLOAD='socket-provider-dev12-xtp14-roundtrip-0000000000000000'

"$REXX_BIN" "$ROOT/tests/test_xtp_dev14_provider_merge.rex"

"$REXX_BIN" "$ROOT/tests/test_xtp_dev14_native_merged.rex" MERGEDPEER listener "$PAYLOAD" >"$TMP/listener.out" 2>"$TMP/listener.err" &
LPID=$!
sleep .2
"$XTP_DEV14_ROOT/bin/xtp-connect" MERGEDPEER --message "$PAYLOAD" >"$TMP/client.out" 2>"$TMP/client.err"
wait "$LPID" || { cat "$TMP/listener.out"; cat "$TMP/listener.err" >&2; exit 30; }
LPID=
cat "$TMP/listener.out"
grep -q '^PASS merged native listener bytes=' "$TMP/listener.out"

"$XTP_DEV14_ROOT/bin/xtp-listen" MERGEDPEER --max 1 >"$TMP/server.out" 2>"$TMP/server.err" &
LPID=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_xtp_dev14_native_merged.rex" MERGEDPEER sender "$PAYLOAD" >"$TMP/sender.out" 2>"$TMP/sender.err"
wait "$LPID" || { cat "$TMP/server.out"; cat "$TMP/server.err" >&2; exit 31; }
LPID=
cat "$TMP/sender.out"
grep -q '^PASS merged native sender bytes=' "$TMP/sender.out"
grep -q 'XTP_ACCEPT .*bytes=' "$TMP/server.out"

echo 'PASS Socket Provider dev12 merged XTP dev14 native sender/listener qualification'


# XTP-specific multipath route remains available through the merged access class.
P1=$((55000 + RANDOM % 200)); P2=$((P1+1))
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\nMERGEDMP\t4\tudp\t127.0.0.1:%d\t\t10\t1\tcrunch\nMERGEDMP\t4\tudp\t127.0.0.1:%d\t\t20\t1\tzero-block,crunch\n' "$P1" "$P2" > "$TMP/routes.tsv"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
MPPAYLOAD='socket-provider-dev12-xtp14-multipath-AAAABBBBCCCCDDDD'

"$REXX_BIN" "$ROOT/tests/test_xtp_dev14_multipath_merged.rex" MERGEDMP listener "$MPPAYLOAD" >"$TMP/mp-listener.out" 2>"$TMP/mp-listener.err" &
LPID=$!
sleep .2
"$XTP_DEV14_ROOT/bin/xtp-multipath" send MERGEDMP --message "$MPPAYLOAD" --chunk 4 --generation 11 --timeout-ms 100 --retries 3 >"$TMP/mp-send.out" 2>"$TMP/mp-send.err"
wait "$LPID" || { cat "$TMP/mp-listener.out"; cat "$TMP/mp-listener.err" >&2; exit 40; }
LPID=
grep -q '^PASS merged native Rexx multipath listener bytes=' "$TMP/mp-listener.out"
cat "$TMP/mp-listener.out"

"$XTP_DEV14_ROOT/bin/xtp-multipath" listen MERGEDMP --paths 2 >"$TMP/mp-native-listener.out" 2>"$TMP/mp-native-listener.err" &
LPID=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_xtp_dev14_multipath_merged.rex" MERGEDMP sender "$MPPAYLOAD" >"$TMP/mp-sender.out" 2>"$TMP/mp-sender.err"
wait "$LPID" || { cat "$TMP/mp-native-listener.out"; cat "$TMP/mp-native-listener.err" >&2; exit 41; }
LPID=
grep -q '^PASS merged native Rexx multipath sender bytes=' "$TMP/mp-sender.out"
grep -q "data=$MPPAYLOAD" "$TMP/mp-native-listener.out"
cat "$TMP/mp-sender.out"

echo 'PASS Socket Provider dev12 merged XTP dev14 multipath qualification'
