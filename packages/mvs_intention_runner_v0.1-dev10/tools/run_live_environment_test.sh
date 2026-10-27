#!/usr/bin/env bash
set -euo pipefail

# Full MVS Intention provider-composition environment qualification.
#
# This harness deliberately does NOT substitute shell/s3270/log scraping for the
# three authorities.  Each adapter command must interrogate its real component
# and emit the canonical safe-discovery TSV feed documented in README.md.
# The harness then runs the ordinary MVS Intention runner over those live feeds.
#
# Required adapter commands:
#   MVS_ALCHEMY_DISCOVERY_CMD
#   TERMINAL_MACHINE_DISCOVERY_CMD
#   HERCULES_SERVICES_DISCOVERY_CMD
#
# Each command receives TARGET as argv[1] and writes TSV to stdout.

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SELF_DIR/.." && pwd)
TARGET=${MVS_INTENTION_TARGET:-ED209Z}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}
RUN_ID=${MVS_INTENTION_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
EVIDENCE_DIR=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-live-evidence/$RUN_ID}
FEED_DIR="$EVIDENCE_DIR/discovery"
mkdir -p "$FEED_DIR"

fail(){ printf 'FAIL %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 1; }
blocked(){ printf 'BLOCKED %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt" >&2; exit 2; }
pass(){ printf 'PASS %s\n' "$*" | tee -a "$EVIDENCE_DIR/summary.txt"; }

[[ -n ${MVS_ALCHEMY_DISCOVERY_CMD:-} ]] || blocked 'MVS_ALCHEMY_DISCOVERY_CMD is not configured'
[[ -n ${TERMINAL_MACHINE_DISCOVERY_CMD:-} ]] || blocked 'TERMINAL_MACHINE_DISCOVERY_CMD is not configured'
[[ -n ${HERCULES_SERVICES_DISCOVERY_CMD:-} ]] || blocked 'HERCULES_SERVICES_DISCOVERY_CMD is not configured'
[[ -f "$OOREXX_DEB" ]] || blocked "ooRexx package not found: $OOREXX_DEB"

collect(){
  local label=$1 command=$2 output=$3
  printf 'COLLECT %s target=%s\n' "$label" "$TARGET" | tee -a "$EVIDENCE_DIR/summary.txt"
  # Command is administrator/controller configuration, never model output.
  bash -lc "$command \"\$1\"" _ "$TARGET" > "$output" || fail "$label discovery adapter failed"
  grep -Eq '^(PROBE|FACT)[[:space:]]' "$output" || fail "$label emitted no discovery records"
  if grep -Ev '^(PROBE|FACT)[[:space:]]|^[[:space:]]*$' "$output" > "$EVIDENCE_DIR/${label}.invalid"; then
    fail "$label emitted non-protocol output"
  fi
  pass "$label discovery"
}

collect MVS_ALCHEMY "$MVS_ALCHEMY_DISCOVERY_CMD" "$FEED_DIR/mvs_alchemy.tsv"
collect TERMINAL_MACHINE "$TERMINAL_MACHINE_DISCOVERY_CMD" "$FEED_DIR/terminal_machine.tsv"
collect HERCULES_SERVICES "$HERCULES_SERVICES_DISCOVERY_CMD" "$FEED_DIR/hercules_services.tsv"

# Every observation entering intention resolution must have been emitted by one
# of the above controller-owned adapters.  Mutation verbs are not part of dev2.
if grep -Eqi $'^(FACT|PROBE).*\t(WRITE|DELETE|SUBMIT|CANCEL|IPL|VARY|SET|MODIFY)(\t|$)' "$FEED_DIR"/*.tsv; then
  fail 'mutation-like discovery record rejected'
fi

WORK=${TMPDIR:-/tmp}/mvs-intention-dev2-live-$RUN_ID
rm -rf "$WORK"; mkdir -p "$WORK"
dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
[[ -n "$REXX" ]] || fail 'rexx not found in supplied package'
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/intention:$ROOT/vendor/intention/nlp"
export MVS_DISCOVERY_DIR="$FEED_DIR"

"$REXX" -v 2>&1 | head -3 | tee "$EVIDENCE_DIR/oorexx-version.txt"
printf 'what system am I on\nwhat can I see\nshow jobs\n\n' | \
  "$REXX" "$ROOT/examples/mvs_intention.rex" "$TARGET" "$FEED_DIR" | tee "$EVIDENCE_DIR/intention-transcript.txt"

grep -q 'STATUS: READY' "$EVIDENCE_DIR/intention-transcript.txt" || fail 'no READY live intention'
grep -q 'DISCOVERY_PROBES:' "$EVIDENCE_DIR/intention-transcript.txt" || fail 'discovery trace missing'
pass "MVS Intention live provider composition target=$TARGET"
printf 'RUN_ID=%s\nEVIDENCE_DIR=%s\n' "$RUN_ID" "$EVIDENCE_DIR" | tee -a "$EVIDENCE_DIR/summary.txt"
