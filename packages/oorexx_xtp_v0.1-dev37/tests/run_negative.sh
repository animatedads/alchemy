#!/usr/bin/env bash
# dev26 negative (adversarial) suite.  Each test must FAIL on dev25 and PASS here.
# Exit codes per test: 0 PASS, 77 SKIP (missing capability), anything else FAIL.
#
# Usage:
#   bash tests/run_negative.sh                 # test this tree
#   SRC_ROOT=/path/to/oorexx_xtp_v0.1-dev25 DEV26=0 bash tests/run_negative.sh
#                                              # prove the same tests fail on dev25
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC_ROOT=${SRC_ROOT:-$ROOT}
DEV26=${DEV26:-1}
PLANNER=${OPERATIONAL_PLANNER_DIR:-$ROOT/../oorexx_operational_degradation_planner_v0.1-dev5}
case "$PLANNER" in /*) ;; *) PLANNER="$ROOT/$PLANNER" ;; esac
CXX=${CXX:-g++}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

if [[ ! -f "$SRC_ROOT/lib/libxtp.a" ]]; then make -s -C "$SRC_ROOT" OPERATIONAL_PLANNER_DIR="$PLANNER" all >/dev/null || exit 2; fi
FLAGS=(-I"$SRC_ROOT/include" -I"$PLANNER/include" -O2 -std=c++17 -pthread)
[[ "$DEV26" == 1 ]] && FLAGS+=(-DXTP_DEV26)
OBJS=("$SRC_ROOT/build/xtp_security.o" "$SRC_ROOT/build/xtp_service.o" "$SRC_ROOT/build/xtp_priority.o" "$SRC_ROOT/build/xtp_wire.o" "$SRC_ROOT/build/xtp_route.o")
TRANSPORT="-DXTP_TRANSPORT_SRC=\"$SRC_ROOT/src/xtp_transport.cpp\""

pass=0; fail=0; skip=0
run(){ # id name source link-mode
  local id=$1 name=$2 src=$3 mode=$4
  local bin="$OUT/$id.bin" log="$OUT/$id.log"
  if [[ $mode == internal ]]; then
    "$CXX" "${FLAGS[@]}" "$TRANSPORT" -o "$bin" "$ROOT/tests/neg/$src" "${OBJS[@]}" -lcrypto >"$log" 2>&1
  else
    "$CXX" "${FLAGS[@]}" -o "$bin" "$ROOT/tests/neg/$src" "$SRC_ROOT/lib/libxtp.a" "$PLANNER/lib/liboperational_planner.a" -lcrypto >"$log" 2>&1
  fi || { echo "FAIL $id $name (did not compile)"; tail -3 "$log"; fail=$((fail+1)); return; }
  timeout 60 "$bin" >"$log" 2>&1; local rc=$?
  if [[ $rc == 0 ]]; then echo "PASS $id $name"; pass=$((pass+1))
  elif [[ $rc == 77 ]]; then echo "SKIP $id $name ($(grep -m1 '^SKIP' "$log"))"; skip=$((skip+1))
  else echo "FAIL $id $name"; sed 's/^/    /' "$log" | tail -4; fail=$((fail+1)); fi
}
run N1    "UDP sender rejects close-ACK from a non-destination port"   neg_spoofed_ack.cpp      internal
run N1-L2 "L2 sender rejects close-ACK from a foreign MAC"             neg_l2_spoofed_ack.cpp   internal
run N1-RTN "sender requires the XTP return bit on a close-ACK"         neg_ack_return_bit.cpp   internal
run N2    "L2 listener ignores frames addressed to a foreign MAC"      neg_l2_foreign_mac.cpp   library
run N8    "operational adapter refuses zero-THROTTLE like the planner" neg_zero_throttle.cpp    library
run E6    "malformed FIRST is dropped; listener keeps serving"         neg_malformed_first.cpp  internal
run E7    "replay per (peer host, KEY, payload), bounded window"        neg_replay_scope.cpp     internal
echo "NEGATIVE SUITE: pass=$pass fail=$fail skip=$skip"
[[ $fail == 0 ]]
