#!/usr/bin/env bash
# Real local Level-2 transaction over a temporary veth pair. Requires CAP_NET_ADMIN + CAP_NET_RAW.
set -euo pipefail
BIN=${1:?usage: remote_l2_selftest.sh /path/to/xtp-local}
A=xtpfa$$
B=xtpfb$$
TMP=$(mktemp -d)
SPID=
cleanup(){ set +e; [[ -n "${SPID:-}" ]] && kill "$SPID" 2>/dev/null; ip link del "$A" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
command -v ip >/dev/null 2>&1 || { echo 'L2_SELFTEST=SKIP_NO_IP'; exit 0; }
ip link add "$A" type veth peer name "$B" || { echo 'L2_SELFTEST=SKIP_NO_NET_ADMIN'; exit 0; }
ip link set "$A" address 02:00:00:36:00:01
ip link set "$B" address 02:00:00:36:00:02
ip link set "$A" up
ip link set "$B" up
"$BIN" server --carrier l2 --interface "$B" --max 1 >"$TMP/s.out" 2>"$TMP/s.err" & SPID=$!
sleep .1
if command -v timeout >/dev/null 2>&1; then
  timeout 6s "$BIN" client --carrier l2 --interface "$A" --to-mac 02:00:00:36:00:02 --message field-l2-selftest --key 28173 --endian big --timeout-ms 400 --retries 6 >"$TMP/c.out" 2>"$TMP/c.err"
else
  "$BIN" client --carrier l2 --interface "$A" --to-mac 02:00:00:36:00:02 --message field-l2-selftest --key 28173 --endian big --timeout-ms 400 --retries 6 >"$TMP/c.out" 2>"$TMP/c.err"
fi
wait "$SPID"; SPID=
cat "$TMP/c.out"
cat "$TMP/s.out"
grep -q 'XTP_OK carrier=l2 key=28173' "$TMP/c.out"
grep -q 'DELIVER carrier=l2 .*key=28173 .*data=field-l2-selftest' "$TMP/s.out"
echo 'L2_SELFTEST=PASS'
