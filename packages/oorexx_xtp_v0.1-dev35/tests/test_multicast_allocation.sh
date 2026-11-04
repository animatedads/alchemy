#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
GROUP=239.192.0.44:29444
"$ROOT/bin/xtp-admin" route add ALLOC --layer 4 --carrier udp --to "$GROUP" --multicast >/dev/null
python3 - <<'PY' >"$TMP/in.bin"
import sys
sys.stdout.buffer.write(bytes((i*37)%251 for i in range(8192)))
PY
"$ROOT/bin/xtp-multicast" listen ALLOC --timeout-ms 5000 --receive-window 512 --output "$TMP/out.bin" >"$TMP/listen.out" 2>"$TMP/listen.err" & LPID=$!
sleep .15
"$ROOT/bin/xtp-multicast" send ALLOC --file "$TMP/in.bin" --expected 1 --timeout-ms 100 --retries 8 --segment-bytes 256 >"$TMP/send.out" 2>"$TMP/send.err"
wait "$LPID"; LPID=
cmp "$TMP/in.bin" "$TMP/out.bin"
grep -q 'XTP_MULTICAST_OK' "$TMP/send.out"
rounds=$(sed -n 's/.*allocation_rounds=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
alloc=$(sed -n 's/.*slowest_alloc=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
[[ -n "$rounds" && "$rounds" -gt 2 ]]
[[ -n "$alloc" && "$alloc" -ge 8192 ]]
echo "PASS multicast sender advances inside receiver ALLOC window rounds=$rounds slowest_alloc=$alloc"
