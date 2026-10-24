#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${1:-${MVS_INTENTION_TARGET:-ED209Z}}
HOST=${2:-${TERMINAL_MACHINE_HOST:-}}
PORT=${3:-${TERMINAL_MACHINE_PORT:-3270}}
LU=${4:-${TERMINAL_MACHINE_LU:-00C0}}
TIMEOUT=${5:-${TERMINAL_MACHINE_TIMEOUT:-15}}
TM_ROOT=${TERMINAL_MACHINE_ROOT:-}
OOREXX_DEB=${OOREXX_DEB:-/mnt/data/oorexx-5.3.0-13196.ubuntu1604debug.x86_64\(20261006-092552\).deb}

[[ -n "$HOST" ]] || { echo "terminal-machine discovery: HOST required" >&2; exit 2; }
[[ -n "$TM_ROOT" && -f "$TM_ROOT/src/TN3270LiveSession.cls" ]] || {
  echo "terminal-machine discovery: TERMINAL_MACHINE_ROOT must point to extracted Terminal Machine v0.22-candidate8" >&2
  exit 2
}
[[ -f "$OOREXX_DEB" ]] || { echo "terminal-machine discovery: ooRexx package not found: $OOREXX_DEB" >&2; exit 2; }

WORK=${TMPDIR:-/tmp}/mvs-intention-dev9-tm-runtime
mkdir -p "$WORK"
if [[ ! -x "$WORK/oorexx/usr/bin/rexx" && ! -x "$WORK/oorexx/usr/local/bin/rexx" ]]; then
  rm -rf "$WORK/oorexx"
  mkdir -p "$WORK/oorexx"
  dpkg-deb -x "$OOREXX_DEB" "$WORK/oorexx"
fi
REXX=$(find "$WORK/oorexx" -type f -path '*/bin/rexx' | head -1)
[[ -n "$REXX" ]] || { echo "terminal-machine discovery: rexx not found" >&2; exit 2; }
RHOME=$(dirname "$(dirname "$REXX")")
export LD_LIBRARY_PATH="$RHOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$TM_ROOT/src${REXX_PATH:+:$REXX_PATH}"
exec "$REXX" "$ROOT/tools/terminal_machine_tso_discovery.rex" "$TARGET" "$HOST" "$PORT" "$LU" "$TIMEOUT"
