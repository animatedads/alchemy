#!/bin/sh
# Compile each mutant (NetRexxC for .nrx, javac for .java) and run SLAM's JUnit class and the random one
# against it. KILLED: a test fails. SURVIVED: all pass. TIMEOUT: past the limit (killed). STILLBORN: the
# mutant does not compile (not counted).
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-29.
# Output lines (tab-separated): unit, mutant, SLAM|RAND, verdict, change
# Args: jobs file | classpath of the original classes and runtime | compiled tests dir | JUnit classpath |
#       NetRexx lib dir | output file | seconds (default 60) | workers (default 2)
set -eu
JOBS=$1; CP=$2; TC=$3; JU=$4; NRLIB=$5; OUT=$6; LIMIT=${7:-60}; P=${8:-2}
export CP TC JU NRLIB LIMIT
: > "$OUT"
tr '\t' '\037' < "$JOBS" | xargs -d '\n' -P "$P" -I{} sh -c '
  IFS=$(printf "\037"); set -- $1
  id=$1; src=$2; pkg=$3; st=$4; rt=$5; change=$6
  d=$(dirname "$src"); cls="$d/classes"; mkdir -p "$cls"
  case "$src" in
    *.nrx) (cd "$d" && timeout -s KILL "$LIMIT" java -cp "$NRLIB/NetRexxC.jar:$NRLIB/ecj-I20201218-1800-NRX-18.jar:$CP" org.netrexx.process.NetRexxC -noconsole "$(basename "$src")" > compile.log 2>&1) || true
           p=$(printf "%s" "$pkg" | tr . /); mkdir -p "$cls/$p"; mv "$d"/*.class "$cls/$p/" 2>/dev/null || true ;;
    *.java) timeout -s KILL "$LIMIT" javac -nowarn -cp "$CP" -d "$cls" "$src" > "$d/compile.log" 2>&1 || true ;;
  esac
  if [ -z "$(find "$cls" -name "*.class" | head -n 1)" ]; then
    printf "%s\t%s\t%s\t%s\t%s\n" "${change%% *}" "$id" "SLAM" "STILLBORN" "$change"; printf "%s\t%s\t%s\t%s\t%s\n" "${change%% *}" "$id" "RAND" "STILLBORN" "$change"; exit 0
  fi
  for kind in SLAM RAND; do
    if [ $kind = SLAM ]; then t=$st; else t=$rt; fi
    o=$(timeout -s KILL "$LIMIT" java -cp "$cls:$TC:$CP:$JU" org.junit.runner.JUnitCore "$t" 2>/dev/null) && rc=0 || rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then v=TIMEOUT
    elif printf "%s\n" "$o" | grep -q "^OK ("; then v=SURVIVED
    else v=KILLED
    fi
    printf "%s\t%s\t%s\t%s\t%s\n" "${change%% *}" "$id" "$kind" "$v" "$change"
  done
' _ {} >> "$OUT"
