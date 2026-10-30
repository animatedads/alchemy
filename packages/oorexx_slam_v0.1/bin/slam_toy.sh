#!/bin/sh
# slam_toy.sh - SLAM's test tools in one command, for a lane that wants to run them on its own code.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-29. See TOY.md.
#
#   sh bin/slam_toy.sh setup
#   sh bin/slam_toy.sh untested  ROOT [TEST-PATTERN ...]
#   sh bin/slam_toy.sh bifcases  OOREXX_SOURCE_ROOT RX2CPP_ROOT OUT_DIR
#   sh bin/slam_toy.sh unittests ROOT OUT_DIR
#
# Needs: ooRexx 5 (rexx on PATH), gcc, make, patch and the SQLite 3 dev files (setup only).
# unittests also needs OOTEST_ROOT: an unzipped ooTest snapshot (holding ooTest.frm and framework/).
# SLAM_TOY_LIB: where setup puts librexxsql.so (default $HOME/.slam_toy/lib).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
P=$(CDPATH= cd -- "$HERE/.." && pwd)
LIB=${SLAM_TOY_LIB:-$HOME/.slam_toy/lib}
export REXX_PATH="$HERE/src:$HERE/vendor/rx2cpp:$HERE/tests/bif:$P/oorexx_rexxsql_backend_v0.1/src:$P/oorexx_native_database_backends_v0.1/src${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cmd=${1:-help}
[ $# -gt 0 ] && shift
case "$cmd" in
  setup)
    sh "$P/oorexx_rexxsql_backend_v0.1/tools/build_rexxsql.sh" "$LIB"
    echo "librexxsql.so is in $LIB"
    ;;
  untested)
    ROOT=${1:?usage: slam_toy.sh untested ROOT [TEST-PATTERN ...]}
    shift
    rexx "$HERE/bin/slam_untested.rex" "$ROOT" "$@"
    ;;
  bifcases)
    SRC=${1:?usage: slam_toy.sh bifcases OOREXX_SOURCE_ROOT RX2CPP_ROOT OUT_DIR}
    RX=${2:?usage: slam_toy.sh bifcases OOREXX_SOURCE_ROOT RX2CPP_ROOT OUT_DIR}
    OUT=${3:?usage: slam_toy.sh bifcases OOREXX_SOURCE_ROOT RX2CPP_ROOT OUT_DIR}
    mkdir -p "$OUT"
    BIF="$RX/external/bif"
    rexx "$HERE/tests/bif/bif_compare.rex" "$SRC/interpreter|$BIF/native/rxbif.cpp|$BIF/tests/differential.cpp|$OUT/bif_cases.txt" > "$OUT/bif_compare.log"
    rexx "$HERE/tools/bif_oracle_programs.rex" "$OUT/bif_cases.txt" "$OUT/programs"
    echo "programs: $OUT/programs (expected interpreter output in $OUT/programs/expected)"
    ;;
  unittests)
    ROOT=${1:?usage: slam_toy.sh unittests ROOT OUT_DIR}
    OUT=${2:?usage: slam_toy.sh unittests ROOT OUT_DIR}
    OT=${OOTEST_ROOT:?set OOTEST_ROOT to an unzipped ooTest snapshot}
    mkdir -p "$OUT"
    ROOT=$(CDPATH= cd -- "$ROOT" && pwd)
    OUT=$(CDPATH= cd -- "$OUT" && pwd)
    rexx "$HERE/tools/find_pool.rex" "$ROOT" "$OUT/pool.txt"
    rexx "$HERE/tests/unit/write_tests.rex" "$ROOT|$OUT/pool.txt|$OUT/groups|$OUT/summary.txt"
    pass=0; fail=0
    for g in "$OUT"/groups/*.testGroup; do
      [ -f "$g" ] || continue
      o=$(cd "$OUT/groups" && REXX_PATH="$OT:$OT/framework:$REXX_PATH" timeout -s KILL 120 rexx "$(basename "$g")" 2>&1) || true
      if printf "%s\n" "$o" | grep -q "^Failures: *0$" && printf "%s\n" "$o" | grep -q "^Errors: *0$"; then pass=$((pass+1)); else fail=$((fail+1)); echo "NOT PASSING on the code as it is: $g"; fi
    done
    echo "ooTest groups passing on the code as it is: $pass, not passing: $fail"
    rexx "$HERE/tests/unit/mutate.rex" "$ROOT|$OUT/summary.txt|$OUT/groups|$OUT/mutants|$OUT/jobs.txt"
    sh "$HERE/tests/unit/run_mutants.sh" "$OUT/jobs.txt" "$OUT/groups/cases.txt" "$OUT/verdicts.txt" 15 2
    rexx "$HERE/tests/unit/score.rex" "$OUT/verdicts.txt|$OUT/score.txt"
    echo "groups: $OUT/groups   score: $OUT/score.txt   survivors: grep SURVIVED $OUT/verdicts.txt"
    ;;
  *)
    sed -n '2,13p' "$0"
    ;;
esac
