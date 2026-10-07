#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
TMP="$(mktemp -d)"; trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
P1=$((53000 + RANDOM % 200)); P2=$((P1+1))
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\nREXXMP\t4\tudp\t127.0.0.1:%d\t\t10\t1\tcrunch\nREXXMP\t4\tudp\t127.0.0.1:%d\t\t20\t1\tzero-block,crunch\n' "$P1" "$P2" > "$TMP/routes.tsv"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/socket_provider${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
PAYLOAD='rexx-multipath-AAAABBBBCCCCDDDD'

"$REXX_BIN" "$ROOT/tests/test_xtp_multipath_native.rex" REXXMP listener "$PAYLOAD" >"$TMP/l.out" 2>"$TMP/l.err" & LPID=$!
sleep .2
"$ROOT/bin/xtp-multipath" send REXXMP --message "$PAYLOAD" --chunk 4 --generation 11 --timeout-ms 100 --retries 3 >"$TMP/s.out" 2>"$TMP/s.err"
wait "$LPID"; LPID=
grep -q '^PASS native Rexx multipath listener bytes=' "$TMP/l.out"

"$ROOT/bin/xtp-multipath" listen REXXMP --paths 2 >"$TMP/cl.out" 2>"$TMP/cl.err" & LPID=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_xtp_multipath_native.rex" REXXMP sender "$PAYLOAD" >"$TMP/rs.out" 2>"$TMP/rs.err"
wait "$LPID"; LPID=
grep -q '^PASS native Rexx multipath sender bytes=' "$TMP/rs.out"
grep -q "data=$PAYLOAD" "$TMP/cl.out"
echo 'PASS native ooRexx multipath hooks -> libxtp'
