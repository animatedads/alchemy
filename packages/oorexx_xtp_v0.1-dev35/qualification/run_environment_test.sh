#!/usr/bin/env bash
# Full real-host XTP carrier qualification.
# Run normally for build/UDP/probe. Run as root (or grant CAP_NET_RAW) to execute native IP protocol 36.
# If CAP_NET_ADMIN is also available and `ip` exists, a private veth pair is created for direct L2 qualification.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN="$ROOT/bin/xtp-local"
TMP=$(mktemp -d)
SPID=
VETH_CREATED=0
cleanup() {
  set +e
  [[ -n "${SPID:-}" ]] && kill "$SPID" 2>/dev/null
  if [[ "$VETH_CREATED" == 1 ]]; then ip link del xtpva 2>/dev/null; fi
  rm -rf "$TMP"
}
trap cleanup EXIT

if [[ "${XTP_SKIP_BUILD:-0}" != 1 ]]; then
  make -C "$ROOT" clean all
fi
printf '%s\n' '== host ==' 
uname -a
id
printf '%s\n' '== carrier capability =='
"$BIN" probe

printf '%s\n' '== regression: XTP over UDP =='
XTP_SKIP_BUILD=1 "$ROOT/tests/run_tests.sh"

printf '%s\n' '== native XTP / IPv4 protocol 36 =='
if "$BIN" probe | grep -q '^RAW36 available'; then
  "$BIN" server --carrier raw36 --bind 127.0.0.1 --max 1 >"$TMP/raw.s.out" 2>"$TMP/raw.s.err" & SPID=$!
  sleep .1
  "$BIN" client --carrier raw36 --from 127.0.0.1 --to 127.0.0.1 --message 'native-protocol-36' --key 36001 --endian little --timeout-ms 500 --retries 8 >"$TMP/raw.c.out" 2>"$TMP/raw.c.err"
  wait "$SPID"; SPID=
  cat "$TMP/raw.c.out"
  cat "$TMP/raw.s.out"
  grep -q 'XTP_OK carrier=raw36 key=36001' "$TMP/raw.c.out"
  grep -q 'DELIVER carrier=raw36 .*key=36001 bytes=18 data=native-protocol-36' "$TMP/raw.s.out"
  echo 'PASS native XTP IPv4 protocol 36 endpoint-to-endpoint'
else
  echo 'SKIP native protocol 36: CAP_NET_RAW unavailable. Run this script as root or grant cap_net_raw to bin/xtp-local.'
  if [[ "${XTP_REQUIRE_RAW36:-0}" == 1 ]]; then exit 4; fi
fi

printf '%s\n' '== direct level-2 carrier over private veth =='
if command -v ip >/dev/null 2>&1 && "$BIN" probe | grep -q '^L2_RAW available'; then
  # veth creation additionally requires CAP_NET_ADMIN/root. We test it rather than assume it.
  if ip link add xtpva type veth peer name xtpvb 2>/dev/null; then
    VETH_CREATED=1
    ip link set xtpva address 02:00:00:00:36:01
    ip link set xtpvb address 02:00:00:00:36:02
    ip link set xtpva up
    ip link set xtpvb up
    "$BIN" server --carrier l2 --interface xtpvb --max 1 >"$TMP/l2.s.out" 2>"$TMP/l2.s.err" & SPID=$!
    sleep .1
    if command -v timeout >/dev/null 2>&1; then
      timeout 8s "$BIN" client --carrier l2 --interface xtpva --to-mac 02:00:00:00:36:02 --message 'direct-level-two' --key 22001 --endian big --timeout-ms 500 --retries 8 >"$TMP/l2.c.out" 2>"$TMP/l2.c.err" || {
        rc=$?; cat "$TMP/l2.c.out"; cat "$TMP/l2.c.err" >&2; cat "$TMP/l2.s.out"; cat "$TMP/l2.s.err" >&2; echo "FAIL level-2 XTP client rc=$rc" >&2; exit "$rc";
      }
    else
      "$BIN" client --carrier l2 --interface xtpva --to-mac 02:00:00:00:36:02 --message 'direct-level-two' --key 22001 --endian big --timeout-ms 500 --retries 8 >"$TMP/l2.c.out" 2>"$TMP/l2.c.err"
    fi
    if command -v timeout >/dev/null 2>&1; then
      timeout 3s tail --pid="$SPID" -f /dev/null || true
    fi
    wait "$SPID"; SPID=
    cat "$TMP/l2.c.out"
    cat "$TMP/l2.s.out"
    grep -q 'XTP_OK carrier=l2 key=22001' "$TMP/l2.c.out"
    grep -q 'DELIVER carrier=l2 .*key=22001 bytes=16 data=direct-level-two' "$TMP/l2.s.out"
    echo 'PASS direct level-2 XTP carrier over veth'
  else
    echo 'SKIP level-2 veth test: CAP_NET_ADMIN unavailable (CAP_NET_RAW alone is not enough to create the private test link).'
    if [[ "${XTP_REQUIRE_L2:-0}" == 1 ]]; then exit 5; fi
  fi
else
  echo 'SKIP level-2 test: AF_PACKET raw sockets or ip(8) unavailable.'
  if [[ "${XTP_REQUIRE_L2:-0}" == 1 ]]; then exit 5; fi
fi

printf '%s\n' '== ooRexx SocketSelector -> XTP real sender ==' 
REXX_CANDIDATE="${REXX_BIN:-}"
if [[ -z "$REXX_CANDIDATE" ]] && command -v rexx >/dev/null 2>&1; then REXX_CANDIDATE="$(command -v rexx)"; fi
if [[ -n "$REXX_CANDIDATE" ]]; then
  REXX_BIN="$REXX_CANDIDATE" "$ROOT/tests/test_socket_selector_xtp.sh"
else
  echo 'SKIP ooRexx SocketSelector XTP qualification: set REXX_BIN to the ooRexx executable.'
  if [[ "${XTP_REQUIRE_REXX:-0}" == 1 ]]; then exit 6; fi
fi

printf '%s\n' '== native ooRexx SocketSelector sender/listener =='
if [[ -n "$REXX_CANDIDATE" && -f "$ROOT/lib/liboorexx_xtp_native.so" ]]; then
  REXX_BIN="$REXX_CANDIDATE" "$ROOT/tests/test_socket_selector_xtp_native.sh"
else
  echo 'SKIP native ooRexx XTP qualification: ooRexx native binding unavailable.'
  if [[ "${XTP_REQUIRE_REXX:-0}" == 1 ]]; then exit 6; fi
fi

printf '%s\n' '== native ooRexx multipath hooks =='
if [[ -n "$REXX_CANDIDATE" && -f "$ROOT/lib/liboorexx_xtp_native.so" ]]; then
  REXX_BIN="$REXX_CANDIDATE" "$ROOT/tests/test_xtp_multipath_native.sh"
else
  echo 'SKIP native ooRexx multipath qualification: ooRexx native binding unavailable.'
  if [[ "${XTP_REQUIRE_REXX:-0}" == 1 ]]; then exit 6; fi
fi

echo 'PASS environment qualification completed'
