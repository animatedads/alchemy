#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_DEB:?set OOREXX_DEB to the ooRexx 5.3.0 r13196 .deb}"
: "${REXXTRONICS_ZIP:?set REXXTRONICS_ZIP to the Rexx-tronics package zip}"
: "${INTENTION_SERVICE_ZIP:?set INTENTION_SERVICE_ZIP to ooRexx Intention Service v0.1-dev11 zip}"
TMP=${TMPDIR:-/tmp}/pcb-planner-env.$$
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
mkdir -p "$TMP/oorexx" "$TMP/rexxtronics" "$TMP/intention"
dpkg-deb -x "$OOREXX_DEB" "$TMP/oorexx"
unzip -q "$REXXTRONICS_ZIP" -d "$TMP/rexxtronics"
unzip -q "$INTENTION_SERVICE_ZIP" -d "$TMP/intention"
REXX_BIN=$(find "$TMP/oorexx" -type f -path '*/bin/rexx' | head -1)
REXXTRONICS_ROOT=$(find "$TMP/rexxtronics" -mindepth 1 -maxdepth 1 -type d | head -1)
INTENTION_SERVICE_ROOT=$(find "$TMP/intention" -mindepth 1 -maxdepth 1 -type d | head -1)
LIBDIR=$(dirname "$(find "$TMP/oorexx" -type f -name librexx.so | head -1)")
[ -n "$REXX_BIN" ] && [ -n "$REXXTRONICS_ROOT" ] && [ -n "$INTENTION_SERVICE_ROOT" ] && [ -n "$LIBDIR" ]
export LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX_BIN" -v | head -3
REXX_BIN="$REXX_BIN" REXXTRONICS_ROOT="$REXXTRONICS_ROOT" INTENTION_SERVICE_ROOT="$INTENTION_SERVICE_ROOT" "$ROOT/run_tests.sh"
# Qualify the exact dev11 primitives PCB Planner now depends on.
export REXX_PATH="$INTENTION_SERVICE_ROOT/src"
for t in test_dynamic_discovery.rex test_transient_surfaces.rex test_evidence_contradictions.rex test_evidence_plan_clarification.rex; do
  "$REXX_BIN" "$INTENTION_SERVICE_ROOT/tests/$t"
done
printf '%s\n' 'PASS PCB Planner dev4 complete environment qualification'
