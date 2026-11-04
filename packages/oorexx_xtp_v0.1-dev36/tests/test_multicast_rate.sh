#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'set +e; [[ -n "${LPID:-}" ]] && kill "$LPID" 2>/dev/null; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
GROUP=239.192.0.45:29445
"$ROOT/bin/xtp-admin" route add RATE --layer 4 --carrier udp --to "$GROUP" --multicast >/dev/null
python3 - <<'PY' >"$TMP/in.bin"
import sys
sys.stdout.buffer.write(bytes((i*53+7)%251 for i in range(4096)))
PY
"$ROOT/bin/xtp-multicast" listen RATE --timeout-ms 5000 --receive-window 4096 --rate 20000 --burst 512 --output "$TMP/out.bin" >"$TMP/listen.out" 2>"$TMP/listen.err" & LPID=$!
sleep .15
"$ROOT/bin/xtp-multicast" send RATE --file "$TMP/in.bin" --expected 1 --timeout-ms 100 --retries 8 --segment-bytes 256 >"$TMP/send.out" 2>"$TMP/send.err"
wait "$LPID"; LPID=
cmp "$TMP/in.bin" "$TMP/out.bin"
grep -q 'XTP_MULTICAST_OK' "$TMP/send.out"
rate=$(sed -n 's/.*slowest_rate=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
burst=$(sed -n 's/.*slowest_burst=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
paced=$(sed -n 's/.*rate_bursts=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
slept=$(sed -n 's/.*rate_sleep_us=\([0-9][0-9]*\).*/\1/p' "$TMP/send.out")
[[ "$rate" == 20000 ]]
[[ "$burst" == 512 ]]
[[ -n "$paced" && "$paced" -gt 0 ]]
[[ -n "$slept" && "$slept" -gt 0 ]]
echo "PASS multicast sender honors receiver RATE/BURST rate=$rate burst=$burst paced_bursts=$paced sleep_us=$slept"
