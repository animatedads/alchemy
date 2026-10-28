#!/bin/sh
# Run NetRexx's qtime.nrx and ooRexx's qtime.rex at the same times, a day in 7-minute steps.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
# Args: NetRexx distribution dir (holds lib/NetRexxC.jar and examples/) | ooRexx source dir | work dir
# The only change to either program: NetRexx's clock is read from -Dqtime.clock when given, and
# ooRexx's EnglishTime class gets one public routine that makes an instance at a given time.
set -eu
NR=$1; SRC=$2; W=$3
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$W/qtime_nrx"
: > "$W/qt_cases.txt"
m=0
while [ $m -lt 1440 ]; do
  s=$(( (m / 7) % 2 * 30 ))
  printf '%02d %02d %02d\n' $((m / 60)) $((m % 60)) $s >> "$W/qt_cases.txt"
  m=$((m + 7))
done
sed 's/^parse Time() hour/clock = System.getProperty("qtime.clock")\nif clock = null then clock = Time()\nparse clock hour/' \
  "$NR/examples/ibm-historic/qtime.nrx" > "$W/qtime_nrx/qtime.nrx"
CP="$NR/lib/NetRexxC.jar:$NR/lib/ecj-I20201218-1800-NRX-18.jar"
(cd "$W/qtime_nrx" && java -cp "$CP" org.netrexx.process.NetRexxC qtime.nrx > compile.log 2>&1)
: > "$W/qt_nrx.txt"
while read hh mm ss; do
  echo "$hh:$mm:$ss $(cd "$W/qtime_nrx" && java -Dqtime.clock=$hh:$mm:$ss -cp "$NR/lib/NetRexxC.jar:." qtime 2>/dev/null)" >> "$W/qt_nrx.txt"
done < "$W/qt_cases.txt"
sed -n '/^::class/,$p' "$SRC/samples/qtime.rex" > "$W/qtime_classes.rex"
printf '%s\n' '::routine englishAt public' '  use arg hh, mm, ss' '  return .EnglishTime~new(2026, 10, 28, hh, mm, ss)~englishTime' >> "$W/qtime_classes.rex"
(cd "$W" && rexx "$HERE/qtime_rexx.rex" qt_cases.txt > qt_rexx.txt)
