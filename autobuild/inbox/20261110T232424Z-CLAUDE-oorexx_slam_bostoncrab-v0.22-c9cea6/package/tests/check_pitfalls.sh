#!/bin/sh
# check_pitfalls.sh - the ooRexx pitfall lint must find every trap in
# tests/pitfall_cases/bad.rex (so it still works), pass good.rex, and find
# nothing in Boston Crab's own sources.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
cd "$(dirname "$0")/.."
n=$(rexx tests/rexx_pitfalls.rex tests/pitfall_cases/bad.rex | grep -c ': P[0-9] ')
[ "$n" = "4" ] || { echo "FAIL the lint found $n of the 4 traps in bad.rex"; exit 1; }
rexx tests/rexx_pitfalls.rex tests/pitfall_cases/good.rex > /dev/null || { echo "FAIL the lint flags good.rex"; exit 1; }
rexx tests/rexx_pitfalls.rex *.rex *.cls wordnet/*.rex tests/*.rex
