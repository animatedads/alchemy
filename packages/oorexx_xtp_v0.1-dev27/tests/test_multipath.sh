#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
export XTP_HEALTH_FILE="$TMP/path-health.tsv"
trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
P1=$((52000 + RANDOM % 300))
P2=$((P1 + 1))
P3=$((P1 + 2))

# A/B striping: both paths live, alternate chunks, one logical delivery.
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\nDUAL\t4\tudp\t127.0.0.1:%d\t\t10\t1\tcrunch\nDUAL\t4\tudp\t127.0.0.1:%d\t\t20\t1\tzero-block,crunch\n' "$P1" "$P2" > "$TMP/dual.tsv"
XTP_ROUTE_FILE="$TMP/dual.tsv" "$ROOT/bin/xtp-multipath" listen DUAL --paths 2 >"$TMP/dual-listen.out" 2>"$TMP/dual-listen.err" & LPID=$!
sleep .1
XTP_ROUTE_FILE="$TMP/dual.tsv" "$ROOT/bin/xtp-multipath" send DUAL --message AAAABBBBCCCCDDDD --chunk 4 --transfer-id 12345 --generation 7 --timeout-ms 100 --retries 3 >"$TMP/dual-send.out" 2>"$TMP/dual-send.err"
wait "$LPID"; LPID=
grep -q 'failovers=0 paths=2' "$TMP/dual-send.out"
grep -q 'PATH index=0 .*assigned=2 delivered=2' "$TMP/dual-send.out"
grep -q 'PATH index=1 .*assigned=2 delivered=2' "$TMP/dual-send.out"
grep -q 'generation=7 .*chunks=4 data=AAAABBBBCCCCDDDD' "$TMP/dual-listen.out"
echo 'PASS multipath A/B striping and reassembly'

# A fails: chunks assigned to A are replayed over surviving B.  The receiver
# only exposes B, proving failover is sender-side transport policy rather than
# an application retry.
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\nFAIL\t4\tudp\t127.0.0.1:%d\t\t20\t1\tcrunch\n' "$P3" > "$TMP/fail-listener.tsv"
printf '#peer\tlayer\tcarrier\tdestination\tinterface\tmetric\tenabled\twire_filters\nFAIL\t4\tudp\t127.0.0.1:59999\t\t10\t1\tcrunch\nFAIL\t4\tudp\t127.0.0.1:%d\t\t20\t1\tcrunch\n' "$P3" > "$TMP/fail-sender.tsv"
XTP_ROUTE_FILE="$TMP/fail-listener.tsv" "$ROOT/bin/xtp-multipath" listen FAIL --paths 2 >"$TMP/fail-listen.out" 2>"$TMP/fail-listen.err" & LPID=$!
sleep .1
XTP_ROUTE_FILE="$TMP/fail-sender.tsv" "$ROOT/bin/xtp-multipath" send FAIL --message 0000111122223333 --chunk 4 --transfer-id 54321 --generation 8 --timeout-ms 40 --retries 1 >"$TMP/fail-send.out" 2>"$TMP/fail-send.err"
wait "$LPID"; LPID=
grep -q 'failovers=2 paths=2' "$TMP/fail-send.out"
grep -q 'PATH index=0 .*failed=1' "$TMP/fail-send.out"
grep -q 'PATH index=1 .*delivered=4 replayed=2 failed=0' "$TMP/fail-send.out"
grep -q 'generation=8 .*chunks=4 data=0000111122223333' "$TMP/fail-listen.out"
echo 'PASS failed A path replays assigned chunks over surviving B'

# Regression for chained filters on binary XMP headers.  Intermediate encoded
# forms may exceed the final logical size and must not be rejected prematurely.
HEX=$(python3 - <<'PY'
import struct
b=b'XMP1'+struct.pack('>I',9)+struct.pack('>Q',123)+struct.pack('>IIII',1,4,16,4)+b'BBBB'
print(b.hex())
PY
)
"$ROOT/bin/xtp-admin" filter roundtrip --filters zero-block,crunch --hex "$HEX" | grep -q 'FILTER_OK logical=36'
echo 'PASS chained wire filters accept binary multipath framing'
