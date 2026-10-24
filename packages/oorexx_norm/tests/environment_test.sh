#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOCKET_ROOT=${SOCKET_PROVIDER_ROOT:-"$ROOT/../oorexx_socket_provider_v0.1-dev10"}
REXX_BIN=${REXX_BIN:-rexx}
REXXC_BIN=${REXXC_BIN:-rexxc}
export REXX_PATH="$SOCKET_ROOT/src:$ROOT/src${REXX_PATH:+:$REXX_PATH}"
NORM_ROOT=${NORM_ROOT:-/usr/local}
NORM_INCLUDE=${NORM_INCLUDE:-$NORM_ROOT/include}
NORM_LIBDIR=${NORM_LIBDIR:-$NORM_ROOT/lib}
export LD_LIBRARY_PATH="$ROOT/lib:$NORM_LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

printf '%s\n' '--- common SocketProvider compile/contracts ---'
"$REXXC_BIN" "$SOCKET_ROOT/src/SocketProvider.cls"
"$REXX_BIN" "$SOCKET_ROOT/tests/test_descriptor_readiness_contract.rex"
"$REXX_BIN" "$ROOT/tests/test_norm_address.rex"
"$REXX_BIN" "$ROOT/tests/test_membership_lifecycle.rex"
"$REXX_BIN" "$ROOT/tests/test_selector_membership_contract.rex"

printf '%s\n' '--- build real libnorm native binding ---'
[ -f "$NORM_INCLUDE/normApi.h" ] || { echo "FAIL missing $NORM_INCLUDE/normApi.h (set NORM_INCLUDE to NRL NORM headers)" >&2; exit 30; }
make -C "$ROOT" clean all OOREXX_ROOT="${OOREXX_ROOT:-/usr/local}" NORM_ROOT="$NORM_ROOT" NORM_INCLUDE="$NORM_INCLUDE" NORM_LIBDIR="$NORM_LIBDIR"

printf '%s\n' '--- NORM provider/native contract ---'
"$REXXC_BIN" "$ROOT/src/NormSocketProvider.cls"
"$REXXC_BIN" "$ROOT/src/NormNativeBinding.cls"
"$REXX_BIN" "$ROOT/tests/test_native_contract.rex"

if [ "${NORM_LIVE_TEST:-0}" != 1 ]; then
  echo 'SKIP live multicast (set NORM_LIVE_TEST=1)'
  exit 0
fi

run_case() {
  label=$1 group=$2 port=$3 iface=$4 source=$5 loss=$6 parity=$7 hold=$8
  out=${TMPDIR:-/tmp}/oorexx-norm-${label}.$$.out
  echo "--- live $label group=$group port=$port interface=$iface source=$source loss=$loss parity=$parity ---"
  "$REXX_BIN" "$ROOT/tests/live_descriptor_receiver.rex" "$group" "$port" "$iface" "$source" 2 20000 >"$out" 2>&1 &
  rpid=$!
  trap 'kill $rpid 2>/dev/null || true; rm -f "$out"' INT TERM EXIT
  sleep 1
  if command -v ip >/dev/null 2>&1; then
    if ip maddr show dev "$iface" 2>/dev/null | grep -F "$group" >/dev/null 2>&1; then
      echo "MEMBERSHIP_VISIBLE|$iface|$group"
    else
      echo "MEMBERSHIP_NOT_LISTED|$iface|$group"
    fi
  fi
  "$REXX_BIN" "$ROOT/tests/live_qualified_sender.rex" "$group" "$port" "$iface" "$source" 1 "$loss" "$parity" "$hold"
  wait "$rpid"
  cat "$out"
  grep -F 'READY_RECEIVE_PASS' "$out" >/dev/null
  rm -f "$out"
  trap - INT TERM EXIT
  echo "PASS $label"
}

IPV4_IFACE=${NORM_INTERFACE:-lo}
run_case ipv4-asm "${NORM_GROUP:-239.255.42.61}" "${NORM_PORT:-47061}" "$IPV4_IFACE" - 0 16 3
run_case ipv4-ssm "${NORM_SSM_GROUP:-232.255.42.62}" "${NORM_SSM_PORT:-47062}" "$IPV4_IFACE" "${NORM_SSM_SOURCE:-127.0.0.1}" 0 16 3
run_case nack-repair "${NORM_REPAIR_GROUP:-239.255.42.63}" "${NORM_REPAIR_PORT:-47063}" "$IPV4_IFACE" - "${NORM_REPAIR_LOSS_PERCENT:-10}" 0 10

if command -v ip >/dev/null 2>&1; then
  IPV6_IFACE=${NORM_IPV6_INTERFACE:-$(ip -6 route show table all 2>/dev/null | awk '$1=="multicast" && $2=="ff00::/8" {print $4; exit}')}
  if [ -n "$IPV6_IFACE" ]; then
    run_case ipv6 "${NORM_IPV6_GROUP:-ff02::114}" "${NORM_IPV6_PORT:-47064}" "$IPV6_IFACE" - 0 16 3
  else
    echo 'SKIP IPv6 multicast: no ff00::/8 multicast route found'
  fi
else
  echo 'SKIP IPv6 multicast route discovery: ip command unavailable'
fi

echo 'PASS complete live libnorm SocketProvider qualification'
