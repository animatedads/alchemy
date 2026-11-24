#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; [[ -n "${SPID:-}" ]] && kill "$SPID" 2>/dev/null; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
GROUP=239.192.0.36:29360

"$ROOT/bin/xtp-admin" route add MCG --layer 4 --carrier udp --to "$GROUP" --multicast --filters zero-block,crunch >/dev/null
"$ROOT/bin/xtp-admin" route list MCG | grep -q $'multicast$'
if "$ROOT/bin/xtp-admin" best-connect MCG >/dev/null 2>&1; then
  echo 'FAIL multicast route leaked into unicast best-connect' >&2; exit 1
fi
echo 'PASS multicast route is explicit and excluded from unicast best-connect'

"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 3000 >"$TMP/l1.out" 2>"$TMP/l1.err" & LPID=$!
sleep .15
"$ROOT/bin/xtp-multicast" send MCG --message 'MMMMMMMMMMMMMMMMMMMM multicast works' --expected 1 --timeout-ms 250 --retries 4 >"$TMP/s1.out"
wait "$LPID"; LPID=
grep -q 'XTP_MULTICAST_OK.*acks=1 required=1' "$TMP/s1.out"
grep -q 'XTP_MULTICAST_DELIVER.*data=MMMMMMMMMMMMMMMMMMMM multicast works' "$TMP/l1.out"
echo 'PASS reliable XTP MULTI transaction, wire filters and acknowledgement quorum'

# Go-back-N retry at the message granularity used by the current libxtp FIRST-transaction profile.
"$ROOT/bin/xtp-multicast" send MCG --message 'late receiver' --expected 1 --timeout-ms 100 --retries 12 >"$TMP/s2.out" 2>"$TMP/s2.err" & SPID=$!
sleep .35
"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 3000 >"$TMP/l2.out" 2>"$TMP/l2.err" & LPID=$!
wait "$SPID"; SPID=
wait "$LPID"; LPID=
ATTEMPTS=$(sed -n 's/.* attempts=\([0-9][0-9]*\).*/\1/p' "$TMP/s2.out")
[[ -n "$ATTEMPTS" && "$ATTEMPTS" -gt 1 ]]
grep -q 'data=late receiver' "$TMP/l2.out"
echo 'PASS multicast replay reaches a receiver that appears after initial transmission'

# NOERR multicast is deliberately one-way: sender does not require CNTL replies.
"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 3000 >"$TMP/l3.out" 2>"$TMP/l3.err" & LPID=$!
sleep .15
"$ROOT/bin/xtp-multicast" send MCG --message 'sensor sample' --noerr --expected 0 >"$TMP/s3.out"
wait "$LPID"; LPID=
grep -q 'acks=0 required=0' "$TMP/s3.out"
grep -q 'data=sensor sample' "$TMP/l3.out"
echo 'PASS XTP MULTI NOERR one-way mode'

# One receiver cannot satisfy a two-receiver reliable quorum.
"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 2000 >"$TMP/l4.out" 2>"$TMP/l4.err" & LPID=$!
sleep .15
set +e
"$ROOT/bin/xtp-multicast" send MCG --message 'quorum check' --expected 2 --timeout-ms 80 --retries 3 >"$TMP/s4.out" 2>"$TMP/s4.err"
RC=$?
set -e
wait "$LPID" 2>/dev/null || true; LPID=
[[ "$RC" -ne 0 ]]
grep -q 'acknowledgement quorum not reached' "$TMP/s4.err"
echo 'PASS reliable multicast fails closed when receiver quorum is not reached'

# Multi-packet stream profile: FIRST plus subsequent DATA packets.  Use a
# non-run-heavy binary pattern so zero-block/crunch do not collapse the payload.
python3 - <<'PY' > "$TMP/stream.in"
import sys
sys.stdout.buffer.write(bytes(33 + (i % 90) for i in range(12000)))
PY
"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 5000 --output "$TMP/stream.out" >"$TMP/stream.listen" 2>"$TMP/stream.listen.err" & LPID=$!
sleep .15
"$ROOT/bin/xtp-multicast" send MCG --file "$TMP/stream.in" --expected 1 --timeout-ms 250 --retries 5 --segment-bytes 512 >"$TMP/stream.send"
wait "$LPID"; LPID=
cmp "$TMP/stream.in" "$TMP/stream.out"
PACKETS=$(sed -n 's/.* packets=\([0-9][0-9]*\).*/\1/p' "$TMP/stream.send")
[[ -n "$PACKETS" && "$PACKETS" -gt 1 ]]
echo 'PASS XTP MULTI FIRST+DATA stream reassembles a binary payload'

# Start the receiver after several sender timeout rounds.  The entire segmented
# sequence is replayed from RSEQ 0 and still reassembles exactly once.
"$ROOT/bin/xtp-multicast" send MCG --file "$TMP/stream.in" --expected 1 --timeout-ms 80 --retries 12 --segment-bytes 512 >"$TMP/stream.late.send" 2>"$TMP/stream.late.err" & SPID=$!
sleep .22
"$ROOT/bin/xtp-multicast" listen MCG --timeout-ms 5000 --output "$TMP/stream.late.out" >"$TMP/stream.late.listen" 2>"$TMP/stream.late.listen.err" & LPID=$!
wait "$SPID"; SPID=
wait "$LPID"; LPID=
cmp "$TMP/stream.in" "$TMP/stream.late.out"
ATTEMPTS=$(sed -n 's/.* attempts=\([0-9][0-9]*\).*/\1/p' "$TMP/stream.late.send")
RETX=$(sed -n 's/.* retransmitted=\([0-9][0-9]*\).*/\1/p' "$TMP/stream.late.send")
[[ -n "$ATTEMPTS" && "$ATTEMPTS" -gt 1 && -n "$RETX" && "$RETX" -gt 0 ]]
echo 'PASS segmented multicast stream replays after receiver absence and delivers once'
