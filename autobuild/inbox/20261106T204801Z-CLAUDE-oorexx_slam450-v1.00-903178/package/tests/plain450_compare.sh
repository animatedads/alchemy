#!/bin/bash
# plain450_compare.sh - is the plain race (orders off) byte-identical to a
# reference? Runs the five-craft race and the 3V3 race, seed 1, 120 s, and
# checks every output file against tests/reference_v099/*.sha256 (recorded on
# v0.99 code, 2026-11-06). A change that should not touch the plain race must
# pass this. Not in integration.json: floating-point output can differ
# between machines, so this is the check on the machine that recorded it.
# Usage: bash tests/plain450_compare.sh [workdir]
# Architecture: Tom Dyer. Written by: Claude (Opus 5.5), 2026-11-06.
HERE=$(cd "$(dirname "$0")/.." && pwd); W=${1:-$(mktemp -d)}; fails=0
ARGS="1 HARBOUR 120 NOWIND BATTERY NONE NONE EYES NUMPY OFF BACKSEAT STATIC NOMAP GROUND HAIKU ON QUAD 500 RECALL ON OFF"
for d in plain5 plain3v3; do
  mkdir -p "$W/$d"; sq=5; [ $d = plain3v3 ] && sq=3V3
  (cd "$HERE" && SLAM450_SQUAD=$sq rexx bin/race450_squad.rex "$W/$d/p" $ARGS > "$W/$d.log" 2>&1)
  if (cd "$W/$d" && sha256sum -c --quiet "$HERE/tests/reference_v099/$d.sha256") && \
     [ "$(ls "$W/$d" | wc -l)" = "$(wc -l < "$HERE/tests/reference_v099/$d.sha256")" ]; then
    echo "PASS $d: $(ls "$W/$d" | wc -l) files byte-identical"
  else echo "FAIL $d"; fails=$((fails+1)); fi
done
exit $fails
