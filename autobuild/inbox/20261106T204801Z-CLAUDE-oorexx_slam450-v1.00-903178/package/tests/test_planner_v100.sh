#!/bin/bash
# test_planner_v100.sh - the en-route height planner (v0.99/v1.00): Foxtrot
# circles the Harbour Bridge "without stopping" for 150 s with a 15 m map
# margin and no craft is lost. (v0.98: Foxtrot flew into the bridge at deck
# height; v1.00 before its fallback: lost again at a 15 m margin.)
# Needs CRAB_WORK (Boston Crab v0.19+); skips (exit 0) without it.
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-06.
HERE=$(cd "$(dirname "$0")/.." && pwd)
if [ -z "$CRAB_WORK" ] || [ ! -f "$CRAB_WORK/order_check.rex" ]; then echo "SKIP test_planner_v100: set CRAB_WORK"; exit 0; fi
W=$(mktemp -d)
(cd "$HERE" && SLAM450_MAP_MARGIN=15 CONTROL_TEAMS=ON SLAM450_ROE=ON rexx bin/race450_squad.rex "$W/s" 1 HARBOUR 150 NOWIND BATTERY NONE NONE EYES NUMPY OFF BACKSEAT STATIC NOMAP GROUND HAIKU ON QUAD 500 RECALL ON OFF "SCRIPT:$HERE/tests/orders_v098/race_script_v019.txt" 20 3 > "$W/log" 2>&1)
lost=$(grep -c "SQUAD OUT" "$W/log"); orb=$(grep -c "ORDER DELIVERED .* A6 .*-> ORBIT" "$W/log")
rm -rf "$W"
if [ "$lost" = 0 ] && [ "$orb" -ge 1 ]; then echo "PASS test_planner_v100: no craft lost, Foxtrot orbiting"; exit 0; fi
echo "FAIL test_planner_v100: lost $lost, orbit delivered $orb"; exit 1
