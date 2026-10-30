#!/bin/sh
# The unit-test round for run_tests.sh: SLAM learns the two frameworks, writes ooTest groups and JUnit
# classes, runs them on the code as it is, then scores them on mutants against random tests of the same
# size. Results go to files under WORK that tests/test_unit.rex checks.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-29.
# Args: WORK REPO OOTEST_ROOT [JUNIT_CP NETREXX_HOME]
#   JUNIT_CP: junit-4.x.jar and hamcrest-core-1.3.jar, colon-separated (the JUnit part is skipped without it)
set -eu
WORK=$1; REPO=$2; OT=$3; JU=${4:-}; NR=${5:-}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
U="$WORK/unit"; mkdir -p "$U"
# 1. what SLAM learns first: ooTest's own groups, read into a store; and a probe of each framework
rexx bin/slam.rex ingest "$WORK/ootest.db" "$OT/ooRexx" > "$U/ingest.txt"
rexx tests/unit/learn_frameworks.rex "$WORK/ootest.db|$OT|$JU|$U/learn|$U/learn.txt"
# 2. ooTest groups for the standalone routines, run on the code as it is
rexx tests/unit/write_tests.rex "$REPO|$ROOT/tests/fixtures/standalone_pool.txt|$U/groups|$U/summary.txt" > "$U/write.txt"
ok=0; bad=0
for g in "$U"/groups/*.testGroup; do
  out=$(cd "$U/groups" && REXX_PATH="$OT:$OT/framework:$REXX_PATH" timeout -s KILL 120 rexx "$(basename "$g")" 2>&1) || true
  f=$(printf "%s\n" "$out" | awk '/^Failures:/{print $2}'); e=$(printf "%s\n" "$out" | awk '/^Errors:/{print $2}')
  if [ "$f" = 0 ] && [ "$e" = 0 ]; then ok=$((ok+1)); else bad=$((bad+1)); fi
done
echo "ORIGINALS $ok $bad" > "$U/originals.txt"
# 3. mutants, both suites on each, and the real framework on a sample
rexx tests/unit/mutate.rex "$REPO|$U/summary.txt|$U/groups|$U/mutants|$U/jobs.txt" > "$U/mutate.txt"
sh tests/unit/run_mutants.sh "$U/jobs.txt" "$U/groups/cases.txt" "$U/verdicts.txt" 15 2
rexx tests/unit/score.rex "$U/verdicts.txt|$U/score.txt"
awk -F'\t' '$4 ~ /_00[12]$/' "$U/jobs.txt" > "$U/jobs_check.txt"
sh tests/unit/run_jobs.sh "$U/jobs_check.txt" "$OT" "$U/verdicts_ootest.txt" 2 30
rexx tests/unit/agree.rex "$U/verdicts.txt|$U/verdicts_ootest.txt" > "$U/agree.txt"
# 4. the untested report on its fixture
rexx bin/slam_untested.rex "$ROOT/tests/fixtures/untested" > "$U/untested.txt"
# 5. JUnit: NetRexx's xclasses utilities, compiled by NetRexxC
if [ -n "$JU" ] && [ -n "$NR" ] && [ -d "$NR/examples/xclasses" ]; then
  X="$WORK/junit"; mkdir -p "$X/src" "$X/classes/xclasses" "$X/tc"
  cp "$NR/examples/xclasses/xmath.nrx" "$NR/examples/xclasses/xstring.nrx" "$X/src/"
  (cd "$X/src" && java -cp "$NR/lib/NetRexxC.jar:$NR/lib/ecj-I20201218-1800-NRX-18.jar" org.netrexx.process.NetRexxC -noconsole xmath.nrx xstring.nrx > compile.log 2>&1)
  mv "$X/src"/*.class "$X/classes/xclasses/"
  CP="$X/classes:$NR/lib/NetRexxC.jar"
  rexx tests/unit/write_junit.rex "NRX|$X/src/xmath.nrx $X/src/xstring.nrx|$CP|$X/out|$X/summary.txt" > "$X/write.txt"
  javac -nowarn -cp "$CP:$JU" -d "$X/tc" $(find "$X/out/test" -name "*.java") > "$X/javac.txt" 2>&1
  for k in SLAM RAND; do
    CL=$(cd "$X/tc" && find . -name "${k}_*Test.class" | sed 's|^\./||; s|\.class$||; s|/|.|g' | tr '\n' ' ')
    echo "$k $(java -cp "$X/tc:$CP:$JU" org.junit.runner.JUnitCore $CL 2>/dev/null | grep -E '^OK|^Tests run')" >> "$X/originals.txt"
  done
  rexx tests/unit/mutate_junit.rex "$X/summary.txt|$X/mut|$X/jobs.txt" > "$X/mutate.txt"
  sh tests/unit/run_junit_mutants.sh "$X/jobs.txt" "$CP" "$X/tc" "$JU" "$NR/lib" "$X/verdicts.txt" 60 2
  rexx tests/unit/score.rex "$X/verdicts.txt|$X/score.txt"
fi
