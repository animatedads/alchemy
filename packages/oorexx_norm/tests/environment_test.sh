#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_ROOT=${SOCKET_PROVIDER_ROOT:-"$ROOT/../oorexx_socket_provider_v0.1-dev8"}
REXX_BIN=${REXX_BIN:-rexx}
REXXC_BIN=${REXXC_BIN:-rexxc}
export REXX_PATH="$SOCKET_ROOT/src:$ROOT/src${REXX_PATH:+:$REXX_PATH}"
NORM_LIBDIR=${NORM_LIBDIR:-${NORM_ROOT:-/usr/local}/lib}
export LD_LIBRARY_PATH="$ROOT/lib:$NORM_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
printf '%s\n' '--- common SocketProvider compile/address contract ---'
"$REXXC_BIN" "$SOCKET_ROOT/src/SocketProvider.cls"
"$REXXC_BIN" "$ROOT/tests/test_norm_address.rex"
"$REXX_BIN" "$ROOT/tests/test_norm_address.rex"
printf '%s\n' '--- build real libnorm native binding ---'
make -C "$ROOT" clean all OOREXX_ROOT="${OOREXX_ROOT:-/usr/local}" NORM_ROOT="${NORM_ROOT:-/usr/local}"
printf '%s\n' '--- NORM provider/native contract ---'
"$REXXC_BIN" "$ROOT/src/NormSocketProvider.cls"
"$REXXC_BIN" "$ROOT/tests/test_native_contract.rex"
"$REXX_BIN" "$ROOT/tests/test_native_contract.rex"
if [ "${NORM_LIVE_TEST:-0}" != 1 ]; then
  echo 'SKIP live multicast (set NORM_LIVE_TEST=1)'
  exit 0
fi
GROUP=${NORM_GROUP:-239.255.42.1}
PORT=${NORM_PORT:-47001}
IFACE=${NORM_INTERFACE:-lo}
OUT=${TMPDIR:-/tmp}/oorexx-norm-live.$$.out
trap 'kill ${RPID:-} 2>/dev/null || true; rm -f "$OUT"' EXIT INT TERM
"$REXX_BIN" "$ROOT/tests/live_receiver.rex" "$GROUP" "$PORT" "$IFACE" 2 >"$OUT" 2>&1 & RPID=$!
sleep 1
"$REXX_BIN" "$ROOT/tests/live_sender.rex" "$GROUP" "$PORT" "$IFACE" 1 'NORM-OO REXX-LIVE-QUALIFICATION'
wait "$RPID"
cat "$OUT"
grep -F 'RECEIVED|NORM-OO REXX-LIVE-QUALIFICATION' "$OUT"
echo 'PASS live libnorm multicast through SocketSelector'
