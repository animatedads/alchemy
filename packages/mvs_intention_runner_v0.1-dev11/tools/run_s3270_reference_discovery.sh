#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RESPONSE=${1:-}
TARGET=${2:-}
HOST=${3:-}
LU=${4:-}
TM_ROOT=${TERMINAL_MACHINE_ROOT:-}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}

[[ -f "$RESPONSE" ]] || { echo "s3270 reference: response file required" >&2; exit 2; }
[[ -n "$TARGET" && -n "$HOST" && -n "$LU" ]] || { echo "s3270 reference: TARGET HOST LU required" >&2; exit 2; }
[[ -n "$TM_ROOT" && -f "$TM_ROOT/src/S3270Reference.cls" ]] || {
  echo "s3270 reference: TERMINAL_MACHINE_ROOT must point to candidate16/current Terminal Machine" >&2
  exit 2
}
[[ -f "$OOREXX_DEB" ]] || { echo "s3270 reference: ooRexx package not found: $OOREXX_DEB" >&2; exit 2; }

WORK=${TMPDIR:-/tmp}/mvs-intention-dev11-s3270-runtime
if [[ ! -d "$WORK/oorexx" ]]; then
  mkdir -p "$WORK/oorexx"
  dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
fi
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
[[ -n "$REXX" ]] || { echo "s3270 reference: rexx not found" >&2; exit 2; }
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$TM_ROOT/src${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$ROOT/tools/s3270_reference_discovery.rex" "$RESPONSE" "$TARGET" "$HOST" "$LU"
