#!/usr/bin/env bash
# Stream interop between this tree and an older one (PEER_ROOT) through a lossy
# UDP relay, as separate processes.  Without PEER_ROOT the test is skipped.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PEER_ROOT=${PEER_ROOT:-}
PLANNER=${OPERATIONAL_PLANNER_DIR:-$ROOT/../oorexx_operational_degradation_planner_v0.1-dev5}
case "$PLANNER" in /*) ;; *) PLANNER="$ROOT/$PLANNER" ;; esac
if [[ -z "$PEER_ROOT" || ! -d "$PEER_ROOT/src" ]]; then echo "SKIP interop with dev27 (set PEER_ROOT to a dev27 source tree)"; exit 0; fi
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
if [[ ! -f "$PEER_ROOT/lib/libxtp.a" ]]; then
  # Build the peer in a scratch copy so the repository tree is never written.
  cp -r "$PEER_ROOT" "$OUT/peer" && make -s -C "$OUT/peer" OPERATIONAL_PLANNER_DIR="$PLANNER" lib/libxtp.a >/dev/null || exit 2
  PEER_ROOT="$OUT/peer"
fi
[[ -f "$ROOT/lib/libxtp.a" ]] || make -s -C "$ROOT" OPERATIONAL_PLANNER_DIR="$PLANNER" lib/libxtp.a >/dev/null || exit 2
build(){ g++ -I"$1/include" -I"$PLANNER/include" -O2 -std=c++17 -pthread -o "$OUT/$2" "$ROOT/tests/tools/$3" "$1/lib/libxtp.a" "$PLANNER/lib/liboperational_planner.a" -lcrypto || exit 2; }
build "$ROOT" send28 stream_send.cpp; build "$ROOT" recv28 stream_recv.cpp
build "$PEER_ROOT" send27 stream_send.cpp; build "$PEER_ROOT" recv27 stream_recv.cpp
g++ -O2 -std=c++17 -o "$OUT/relay" "$ROOT/tests/tools/lossy_relay.cpp" || exit 2
version_of(){ sed -n 's/^  "version": *"\([^"]*\)".*/\1/p' "$1/CAPABILITIES.json" | head -1; }
THIS_VER=$(version_of "$ROOT"); PEER_VER=$(version_of "$PEER_ROOT")
fail=0
case_run(){ # id label sender receiver port
  local name=$1 label=$2 snd=$3 rcv=$4 port=$5
  "$OUT/$rcv" 127.0.0.1:$port 150000 77 20000 >"$OUT/$name.r" 2>/dev/null & local rp=$!
  "$OUT/relay" $((port+1)) $port 5 7 25 >"$OUT/$name.y" & local yp=$!
  sleep .2
  "$OUT/$snd" 127.0.0.1:$((port+1)) 150000 77 1024 150 60 >"$OUT/$name.s" 2>/dev/null; local src=$?
  wait $rp; local rrc=$?; kill $yp 2>/dev/null; wait $yp 2>/dev/null
  if [[ $src == 0 && $rrc == 0 ]]; then echo "PASS $name $label: $(cat "$OUT/$name.s") $(cat "$OUT/$name.r")"; else echo "FAIL $name $label: sender=[$(cat "$OUT/$name.s")] receiver=[$(cat "$OUT/$name.r")]"; fail=1; fi
}
case_run I1 "$THIS_VER sender to $PEER_VER receiver, 150 KB, 20%/14% loss" send28 recv27 45701
case_run I2 "$PEER_VER sender to $THIS_VER receiver, 150 KB, 20%/14% loss" send27 recv28 45711
case_run I3 "$THIS_VER sender to $THIS_VER receiver, 150 KB, 20%/14% loss" send28 recv28 45721
exit $fail
