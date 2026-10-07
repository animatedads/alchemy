#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/bin/xtp-local"
PROXY=${QF_PROXY_INTERCEPTOR:-/mnt/data/oorexx_queue_fabric_proxy_interceptor_v0.1-dev1/bin/qf-proxy-interceptor}
TMP=$(mktemp -d)
export XTP_HEALTH_FILE="$TMP/path-health.tsv"
trap 'set +e; [[ -n "${SPID:-}" ]] && kill "$SPID" 2>/dev/null; [[ -n "${PPID2:-}" ]] && kill "$PPID2" 2>/dev/null; rm -rf "$TMP"' EXIT

if [[ "${XTP_SKIP_BUILD:-0}" != 1 ]]; then
  make -C "$ROOT" clean all >/dev/null
fi

# 1. Direct little-endian fast transaction.
"$BIN" server --bind 127.0.0.1:29136 --max 1 >"$TMP/s1.out" 2>"$TMP/s1.err" & SPID=$!
sleep .05
"$BIN" client --to 127.0.0.1:29136 --message hello-xtp --key 1001 --endian little >"$TMP/c1.out" 2>"$TMP/c1.err"
wait "$SPID"; SPID=
grep -q 'XTP_OK' "$TMP/c1.out"; grep -q 'DELIVER carrier=udp key=1001 bytes=9 wire_bytes=9 data=hello-xtp' "$TMP/s1.out"
echo 'PASS direct little-endian transaction'

# 2. Direct big-endian header/data representation.
"$BIN" server --bind 127.0.0.1:29137 --max 1 >"$TMP/s2.out" 2>"$TMP/s2.err" & SPID=$!
sleep .05
"$BIN" client --to 127.0.0.1:29137 --message big-endian --key 1002 --endian big >"$TMP/c2.out" 2>"$TMP/c2.err"
wait "$SPID"; SPID=
grep -q 'endian=big' "$TMP/c2.out"; grep -q 'data=big-endian' "$TMP/s2.out"
echo 'PASS direct big-endian transaction'

# 3. Through transparent proxy with deterministic loss/repeat/delay/jitter.
if [[ -x "$PROXY" ]]; then
  "$BIN" server --bind 127.0.0.1:29138 --max 1 >"$TMP/s3.out" 2>"$TMP/s3.err" & SPID=$!
  "$PROXY" --mode udp --listen 127.0.0.1:29139 --target 127.0.0.1:29138 --seed 7719 --drop 18 --repeat 35 --delay-ms 3 --jitter-ms 7 >"$TMP/p3.out" 2>"$TMP/p3.err" & PPID2=$!
  sleep .1
  "$BIN" client --to 127.0.0.1:29139 --message hostile-network --key 1003 --timeout-ms 120 --retries 40 >"$TMP/c3.out" 2>"$TMP/c3.err"
  wait "$SPID"; SPID=
  kill "$PPID2" 2>/dev/null || true; wait "$PPID2" 2>/dev/null || true; PPID2=
  grep -q 'XTP_OK' "$TMP/c3.out"; grep -q 'DELIVER carrier=udp key=1003 bytes=15 wire_bytes=15 data=hostile-network' "$TMP/s3.out"
  # Duplication may or may not occur on this exact short exchange, so replay suppression is separately proven below.
  echo 'PASS proxied loss/repeat/delay transaction'
else
  echo 'SKIP proxy stress (proxy binary not found)'
fi

# 4. Corruption is rejected by XTP integrity checks and recovered by retry.
if [[ -x "$PROXY" ]]; then
  "$BIN" server --bind 127.0.0.1:29140 --max 1 >"$TMP/s4.out" 2>"$TMP/s4.err" & SPID=$!
  "$PROXY" --mode udp --listen 127.0.0.1:29141 --target 127.0.0.1:29140 --seed 6061 --corrupt 22 --delay-ms 1 >"$TMP/p4.out" 2>"$TMP/p4.err" & PPID2=$!
  sleep .1
  "$BIN" client --to 127.0.0.1:29141 --message checksum-recovery --key 1004 --timeout-ms 100 --retries 50 >"$TMP/c4.out" 2>"$TMP/c4.err"
  kill "$PPID2" 2>/dev/null || true; wait "$PPID2" 2>/dev/null || true; PPID2=
  wait "$SPID"; SPID=
  grep -q 'XTP_OK' "$TMP/c4.out"; grep -q 'data=checksum-recovery' "$TMP/s4.out"
  echo 'PASS checksum rejection/retry under corruption'
fi

# 5. Explicit replay: the same KEY is acknowledged twice but delivered only once.
"$BIN" server --bind 127.0.0.1:29142 >"$TMP/s5.out" 2>"$TMP/s5.err" & SPID=$!
sleep .05
"$BIN" client --to 127.0.0.1:29142 --message once-only --key 1005 --timeout-ms 100 --retries 3 >"$TMP/c5a.out" 2>"$TMP/c5a.err"
"$BIN" client --to 127.0.0.1:29142 --message once-only --key 1005 --timeout-ms 100 --retries 3 >"$TMP/c5b.out" 2>"$TMP/c5b.err"
sleep .05
kill "$SPID" 2>/dev/null || true; wait "$SPID" 2>/dev/null || true; SPID=
[[ $(grep -c '^DELIVER carrier=udp key=1005' "$TMP/s5.out") -eq 1 ]]
grep -q 'XTP_REPLAY_SUPPRESSED key=1005' "$TMP/s5.err"
grep -q 'XTP_OK' "$TMP/c5a.out"; grep -q 'XTP_OK' "$TMP/c5b.out"
echo 'PASS replay acknowledged without duplicate application delivery'

echo 'PASS all local XTP-over-UDP qualification tests'

# dev3 regression: the L2 sender and receiver must use the assigned XTP EtherType consistently.
if grep -R --line-number -E '0x88B5|0x88[^0-9A-Fa-f]*B5' "$ROOT/src" >/tmp/xtp_stale_ethertype.$$ 2>/dev/null; then
  cat /tmp/xtp_stale_ethertype.$$ >&2
  rm -f /tmp/xtp_stale_ethertype.$$
  echo 'FAIL stale experimental EtherType found in source' >&2
  exit 1
fi
rm -f /tmp/xtp_stale_ethertype.$$ 2>/dev/null || true
grep -q 'XTP_ETHERTYPE=0x817D' "$ROOT/src/xtp_local.cpp"
echo 'PASS XTP Layer-2 EtherType is consistently 0x817D'

# 6. Wire filter core: a zero block must collapse and round-trip exactly.
ZEROHEX=$(python3 - <<'PY'
print('00' * 4096)
PY
)
FOUT=$("$ROOT/bin/xtp-admin" filter roundtrip --filters zero-block --hex "$ZEROHEX")
echo "$FOUT" | grep -q 'FILTER_OK logical=4096'
WIRE=$(echo "$FOUT" | sed -n 's/.* wire=\([0-9][0-9]*\).*/\1/p')
[[ "$WIRE" -lt 64 ]]
echo 'PASS zero-block wire filter collapses 4KiB zero run and round-trips'

# 7. Crunch must round-trip repeated non-zero data.
FOUT=$("$ROOT/bin/xtp-admin" filter roundtrip --filters crunch --hex "$(python3 - <<'PY'
print('41' * 2048)
PY
)")
echo "$FOUT" | grep -q 'FILTER_OK logical=2048'
WIRE=$(echo "$FOUT" | sed -n 's/.* wire=\([0-9][0-9]*\).*/\1/p')
[[ "$WIRE" -lt 64 ]]
echo 'PASS crunch wire filter round-trips repeated data'

# 8. Chain order is encoded on wire and reversed automatically at receive.
"$BIN" server --carrier udp --bind 127.0.0.1:29143 --max 1 >"$TMP/s8.out" 2>"$TMP/s8.err" & SPID=$!
sleep .05
"$BIN" client --carrier udp --to 127.0.0.1:29143 --message 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' --key 1008 --filters zero-block,crunch >"$TMP/c8.out" 2>"$TMP/c8.err"
wait "$SPID"; SPID=
grep -q 'data=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "$TMP/s8.out"
grep -q 'wire_bytes=' "$TMP/c8.out"
echo 'PASS self-describing wire envelope crosses real XTP/UDP path and restores application bytes'

# 9. Route graph: best-connect prefers closest enabled layer, then metric.
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add PEER1 --layer 4 --carrier udp --to 192.0.2.9:43601 --metric 10 >/dev/null
"$ROOT/bin/xtp-admin" route add PEER1 --layer 3 --carrier raw36 --to 192.0.2.9 --metric 50 >/dev/null
"$ROOT/bin/xtp-admin" route add PEER1 --layer 2 --carrier l2 --to 02:00:00:00:00:09 --interface xtp0 --metric 100 >/dev/null
BEST=$("$ROOT/bin/xtp-admin" best-connect PEER1)
echo "$BEST" | grep -q 'layer=2 carrier=l2'
"$ROOT/bin/xtp-admin" route remove PEER1 --layer 2 >/dev/null
BEST=$("$ROOT/bin/xtp-admin" best-connect PEER1)
echo "$BEST" | grep -q 'layer=3 carrier=raw36'
echo 'PASS best-connect route policy defaults toward metal then L3 then L4'

# 10. Route objects carry the socket-layer wire profile, and best-paths exposes
# the whole ordered path set rather than flattening transport choice.
export XTP_ROUTE_FILE="$TMP/routes-dev7.tsv"
"$ROOT/bin/xtp-admin" route add PEER2 --layer 4 --carrier udp --to 127.0.0.1:29144 --metric 5 --filters zero-block,crunch >/dev/null
"$ROOT/bin/xtp-admin" route add PEER2 --layer 3 --carrier raw36 --to 192.0.2.44 --metric 50 --filters crunch >/dev/null
PATHS=$("$ROOT/bin/xtp-admin" best-paths PEER2)
echo "$PATHS" | sed -n '1p' | grep -q 'layer=3 carrier=raw36.*filters=crunch'
echo "$PATHS" | sed -n '2p' | grep -q 'layer=4 carrier=udp.*filters=zero-block,crunch'
JSON=$("$ROOT/bin/xtp-admin" route list PEER2 --json)
python3 - "$JSON" <<'PY'
import json,sys
r=json.loads(sys.argv[1])
assert len(r)==2
assert {x['wire_filters'] for x in r} == {'crunch','zero-block,crunch'}
PY
echo 'PASS route graph retains wire-filter profile and exposes ordered path set'

# 11. Disable/enable is part of the route graph.  best-connect must immediately
# fail over to the next permitted layer and return when the preferred route is re-enabled.
"$ROOT/bin/xtp-admin" route disable PEER2 --layer 3 >/dev/null
BEST=$("$ROOT/bin/xtp-admin" best-connect PEER2)
echo "$BEST" | grep -q 'layer=4 carrier=udp'
"$ROOT/bin/xtp-admin" route enable PEER2 --layer 3 >/dev/null
BEST=$("$ROOT/bin/xtp-admin" best-connect PEER2)
echo "$BEST" | grep -q 'layer=3 carrier=raw36'
echo 'PASS route state failover/rejoin changes best-connect without application policy changes'

# 12. The library, not xtp-local, must own L4 send.  xtp-connect uses
# SocketProvider -> best_connect -> libxtp transport -> per-route WireFilterChain.
export XTP_ROUTE_FILE="$TMP/routes-send.tsv"
"$ROOT/bin/xtp-admin" route add LOOP --layer 4 --carrier udp --to 127.0.0.1:29144 --metric 10 --filters crunch >/dev/null
"$BIN" server --carrier udp --bind 127.0.0.1:29144 --max 1 >"$TMP/s12.out" 2>"$TMP/s12.err" & SPID=$!
sleep .05
"$ROOT/bin/xtp-connect" LOOP --message 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' --key 1012 >"$TMP/c12.out" 2>"$TMP/c12.err"
wait "$SPID"; SPID=
grep -q 'XTP_CONNECT_OK peer=LOOP layer=4 carrier=udp' "$TMP/c12.out"
grep -q 'filters=crunch' "$TMP/c12.out"
grep -q 'data=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB' "$TMP/s12.out"
LOGICAL=$(sed -n 's/.* bytes=\([0-9][0-9]*\) wire_bytes=.*/\1/p' "$TMP/c12.out")
WIRE=$(sed -n 's/.* wire_bytes=\([0-9][0-9]*\).*/\1/p' "$TMP/c12.out")
[[ "$WIRE" -lt "$LOGICAL" ]]
echo 'PASS SocketProvider library best-connect performs filtered L4 XTP transaction'

# 13. Backward compatibility: a dev6 seven-column route table remains readable.
cat >"$TMP/dev6-routes.tsv" <<'EOF6'
#peer	layer	carrier	destination	interface	metric	enabled
OLDPEER	4	udp	127.0.0.1:29999		20	1
EOF6
export XTP_ROUTE_FILE="$TMP/dev6-routes.tsv"
OLD=$("$ROOT/bin/xtp-admin" best-connect OLDPEER)
echo "$OLD" | grep -q 'layer=4 carrier=udp.*filters=$'
echo 'PASS dev6 route table is accepted with empty dev7 wire profile'

# 14. dev9: receive/acknowledge/replay semantics now live in libxtp itself.
"$ROOT/tests/test_libxtp_listener.sh"

# 15. dev11: dual-path striping, survivor replay, and binary filter framing.
"$ROOT/tests/test_multipath.sh"

# 16. dev12: persistent path health, explicit requalification, generation-fenced rejoin.
"$ROOT/tests/test_path_health.sh"

# 17. dev13: provider-aware live qualification before path rejoin.
"$ROOT/tests/test_requalification.sh"

# dev16: XTP MULTI FIRST+DATA streaming, reliable quorum, retry and NOERR.
"$ROOT/tests/test_multicast.sh"
"$ROOT/tests/test_multicast_allocation.sh"
"$ROOT/tests/test_multicast_rate.sh"
"$ROOT/tests/test_multicast_reject_suppression.sh"
"$ROOT/tests/test_capability_contract.sh"
"$ROOT/tests/test_xtp_multicast_native.sh"
"$ROOT/tests/test_xtp_multicast_rate_native.sh"

# dev17: current Socket Provider dev12 contract expresses multicast streaming
# as the conjunction requireStream + requireMulticast; no synthetic
# multicastStream field is introduced into the common selector API.
if [[ -n "${REXX_BIN:-}" && -x "${REXX_BIN}" ]]; then
  (cd "$ROOT/tests" && "${REXX_BIN}" ./test_socket_selector_xtp_dev17_capability.rex)
else
  echo 'SKIP SocketSelector XTP dev17 capability negotiation (REXX_BIN unavailable)'
fi
