#!/usr/bin/env bash
set -euo pipefail

# Complete dual-guest reference qualification.
#
# Exercises ED209Z and ED209ZZ independently through the same authenticated,
# read-only x3270/TSO reference path.  The script deliberately gives each guest
# a separate evidence directory and then verifies that target/host/session facts
# do not cross between them.
#
# This is a reference qualification harness only.  It does not claim Terminal
# Machine, MVS Alchemy, Hercules Services, or mutation authority.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OOREXX_DEB=${OOREXX_DEB:-/home/hc3/Downloads/oorexx-5.3.0-13196.ubuntu1604debug.x86_64.deb}
TSO_USER=${TSO_USER:-HERC03}
TSO_PASSWORD=${TSO_PASSWORD:-}
[[ -n "$TSO_PASSWORD" ]] || { echo "BLOCKED TSO_PASSWORD is required at runtime; no packaged default exists" >&2; exit 2; }
BASE_EVIDENCE=${MVS_INTENTION_EVIDENCE_DIR:-$PWD/mvs-intention-dual-live/$(date -u +%Y%m%dT%H%M%SZ)}
mkdir -p "$BASE_EVIDENCE"

run_one(){
  local target=$1 host=$2 expected_other=$3
  local evidence="$BASE_EVIDENCE/$target"
  printf '\n=== %s @ %s ===\n' "$target" "$host"
  MVS_INTENTION_TARGET="$target" \
  X3270_HOST="$host" X3270_PORT=3270 X3270_LU=00C0 \
  TSO_USER="$TSO_USER" TSO_PASSWORD="$TSO_PASSWORD" \
  OOREXX_DEB="$OOREXX_DEB" \
  MVS_INTENTION_EVIDENCE_DIR="$evidence" \
  MVS_INTENTION_RUN_ID="${target}-dual" \
    "$ROOT/tools/run_x3270_tso_intention_live.sh"

  local feed="$evidence/discovery/reference_tso_x3270.tsv"
  [[ -s "$feed" ]] || { echo "FAIL $target emitted no authenticated feed" >&2; return 1; }
  grep -q $'^FACT\tSESSION\tTARGET\t'"$target"$'\t' "$feed" || {
    echo "FAIL $target feed does not assert its own target" >&2; return 1; }
  grep -q $'^FACT\tSESSION\tHOST\t'"$host"$'\t' "$feed" || {
    echo "FAIL $target feed does not assert expected host $host" >&2; return 1; }
  if grep -Fq "$expected_other" "$feed"; then
    echo "FAIL $target feed contains evidence for the other guest/host: $expected_other" >&2
    return 1
  fi
  echo "PASS $target target/host/session separation"
}

[[ -f "$OOREXX_DEB" ]] || { echo "BLOCKED ooRexx package not found: $OOREXX_DEB" >&2; exit 2; }
command -v s3270 >/dev/null 2>&1 || { echo 'BLOCKED s3270 is required' >&2; exit 2; }

run_one ED209Z 52.146.17.8 20.114.63.150
run_one ED209ZZ 20.114.63.150 52.146.17.8

printf '\nPASS dual MVS authenticated reference qualification\nEVIDENCE_DIR=%s\n' "$BASE_EVIDENCE"
