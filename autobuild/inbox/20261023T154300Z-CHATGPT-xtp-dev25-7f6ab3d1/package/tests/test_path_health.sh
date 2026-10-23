#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'set +e; for p in ${PIDS:-}; do kill "$p" 2>/dev/null; done; rm -rf "$TMP"' EXIT
read -r P1 P2 < <(python3 - <<'PYPORT'
import socket
s=[]; ports=[]
for _ in range(2):
    x=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); x.bind(('127.0.0.1',0)); s.append(x); ports.append(x.getsockname()[1])
print(*ports)
for x in s: x.close()
PYPORT
)
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\n' > "$XTP_ROUTE_FILE"
printf 'HEALTH\t4\tudp\t127.0.0.1:%d\t\t10\t1\tcrunch\n' "$P1" >> "$XTP_ROUTE_FILE"
printf 'HEALTH\t4\tudp\t127.0.0.1:%d\t\t20\t1\tcrunch\n' "$P2" >> "$XTP_ROUTE_FILE"

# First transfer: A is absent, B survives. The failure must persist as DOWN.
printf '#peer	layer	carrier	destination	interface	metric	enabled	wire_filters
HEALTH	4	udp	127.0.0.1:%d		20	1	crunch
' "$P2" > "$TMP/listener-b.tsv"
XTP_ROUTE_FILE="$TMP/listener-b.tsv" XTP_HEALTH_FILE="$TMP/listener-health.tsv" "$ROOT/bin/xtp-multipath" listen HEALTH --paths 1 >"$TMP/l1.out" 2>"$TMP/l1.err" & PIDS=$!
sleep .2
"$ROOT/bin/xtp-multipath" send HEALTH --message AAAABBBB --chunk 4 --transfer-id 7001 --timeout-ms 30 --retries 1 >"$TMP/s1.out" 2>"$TMP/s1.err"
wait $PIDS; PIDS=
grep -q 'failovers=1 paths=2' "$TMP/s1.out"
STATE=$("$ROOT/bin/xtp-admin" path list HEALTH)
echo "$STATE" | grep -q "127.0.0.1:$P1.*DOWN"
echo 'PASS failed path persists DOWN beyond one transfer'

# Second transfer: the library must omit A automatically rather than retesting it.
XTP_ROUTE_FILE="$TMP/listener-b.tsv" XTP_HEALTH_FILE="$TMP/listener-health2.tsv" "$ROOT/bin/xtp-multipath" listen HEALTH --paths 1 >"$TMP/l2.out" 2>"$TMP/l2.err" & PIDS=$!
sleep .2
"$ROOT/bin/xtp-multipath" send HEALTH --message CCCCDDDD --chunk 4 --transfer-id 7002 --timeout-ms 30 --retries 1 >"$TMP/s2.out" 2>"$TMP/s2.err"
wait $PIDS; PIDS=
grep -q 'failovers=0 paths=1' "$TMP/s2.out"
echo 'PASS DOWN path is excluded from subsequent best_paths selection'

# dev12 regression keeps the explicit state-machine mechanics isolated.
# dev13 separately proves live carrier qualification. PROBING is not eligible;
# the explicit force-up escape hatch increments generation before rejoin.
"$ROOT/bin/xtp-admin" path probe HEALTH --layer 4 --carrier udp --to "127.0.0.1:$P1" >/dev/null
"$ROOT/bin/xtp-admin" path list HEALTH | grep -q "127.0.0.1:$P1.*PROBING"
UP=$("$ROOT/bin/xtp-admin" path force-up HEALTH --layer 4 --carrier udp --to "127.0.0.1:$P1")
echo "$UP" | grep -q 'generation=2'

# Both paths are live now. One multipath listener owns both carriers. The
# automatically-derived transfer generation must move to 2 before A is
# admitted back into the stripe.
XTP_HEALTH_FILE="$TMP/listener-rejoin-health.tsv" "$ROOT/bin/xtp-multipath" listen HEALTH --paths 2 >"$TMP/l3.out" 2>"$TMP/l3.err" & PIDS=$!
sleep .2
"$ROOT/bin/xtp-multipath" send HEALTH --message EEEEFFFF --chunk 4 --transfer-id 7003 --timeout-ms 50 --retries 2 >"$TMP/s3.out" 2>"$TMP/s3.err"
wait $PIDS; PIDS=
grep -q 'generation=2 .*failovers=0 paths=2' "$TMP/s3.out"
grep -q 'PATH index=0 .*assigned=1 delivered=1' "$TMP/s3.out"
grep -q 'PATH index=1 .*assigned=1 delivered=1' "$TMP/s3.out"
grep -q 'generation=2 .*data=EEEEFFFF' "$TMP/l3.out"
echo 'PASS requalified path rejoins only after generation increment' 
