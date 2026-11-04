#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
LPID=
cleanup(){ set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
PORT=$(python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PY
)
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
cat >"$XTP_ROUTE_FILE" <<EOFROUTE
#peer	layer	carrier	destination	interface	metric	enabled	wire_filters
QUAL	4	udp	127.0.0.1:$PORT		10	1	zero-block,crunch
EOFROUTE

# Put the path down first. A normal state flip is not enough to return it.
"$ROOT/bin/xtp-admin" path down QUAL --layer 4 --carrier udp --to "127.0.0.1:$PORT" --error simulated >/dev/null
"$ROOT/bin/xtp-admin" path list QUAL | grep -q 'DOWN'

# Listener waits for one application message. It must ACK and swallow the
# qualification transaction, then remain alive for the real payload.
"$ROOT/bin/xtp-listen" QUAL --count 1 --timeout-ms 2000 >"$TMP/listen.out" 2>"$TMP/listen.err" & LPID=$!
sleep .1
Q=$("$ROOT/bin/xtp-admin" path qualify QUAL --layer 4 --carrier udp --to "127.0.0.1:$PORT" --timeout-ms 100 --retries 4)
echo "$Q" | grep -q 'PATH_QUALIFIED'
echo "$Q" | grep -q 'provider=l4'
echo "$Q" | grep -q 'method=udp-encapsulated-first-cntl'
echo "$Q" | grep -q 'generation=2'

# Real application data must be the only delivered record.
"$ROOT/bin/xtp-connect" QUAL --message application-after-qualification --key 13001 >/dev/null
wait "$LPID"; LPID=
grep -q 'data=application-after-qualification' "$TMP/listen.out"
[[ $(grep -c '^XTP_ACCEPT ' "$TMP/listen.out") -eq 1 ]]
! grep -q 'XTPQ1' "$TMP/listen.out"
"$ROOT/bin/xtp-admin" path list QUAL | grep -q $'UP\t2\t1\t'
echo 'PASS live L4 qualification is ACKed, hidden from application, and generation-fences rejoin'

# A live qualifier with no remote listener must fail closed and leave DOWN.
PORT2=$(python3 - <<'PY'
import socket
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PY
)
"$ROOT/bin/xtp-admin" route add FAILQUAL --layer 4 --carrier udp --to "127.0.0.1:$PORT2" --metric 10 >/dev/null
set +e
"$ROOT/bin/xtp-admin" path qualify FAILQUAL --layer 4 --carrier udp --to "127.0.0.1:$PORT2" --timeout-ms 20 --retries 1 >"$TMP/fail.out" 2>"$TMP/fail.err"
RC=$?
set -e
[[ "$RC" -eq 7 ]]
"$ROOT/bin/xtp-admin" path list FAILQUAL | grep -q 'DOWN'
grep -q 'PATH_QUALIFY_FAILED' "$TMP/fail.err"
echo 'PASS failed live qualification leaves path DOWN'
