#!/bin/sh
# Translate every NetRexx example (and sysutils.nrx) to Java with NetRexxC -keep -nocompile, keeping
# each file's place: examples/... and sysutils/... under the work dir (the held-out split uses the path).
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
# Args: NetRexx distribution dir | sysutils.nrx | work dir
set -eu
NR=$1; SYS=$2; W=$3
rm -rf "$W"; mkdir -p "$W/sysutils"
(cd "$NR" && find examples -name '*.nrx') | while read f; do
  mkdir -p "$W/$(dirname "$f")"; cp "$NR/$f" "$W/$f"
done
cp "$SYS" "$W/sysutils/"
CP="$NR/lib/NetRexxC.jar:$NR/lib/ecj-I20201218-1800-NRX-18.jar"
(cd "$W" && find . -name '*.nrx' -exec dirname {} \; | sort -u) | while read d; do
  (cd "$W/$d" && java -cp "$CP" org.netrexx.process.NetRexxC -keep -nocompile -noconsole *.nrx > translate.log 2>&1) || true
done
