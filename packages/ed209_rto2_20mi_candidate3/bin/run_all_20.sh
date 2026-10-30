#!/usr/bin/env bash
# Start the fleet job from the designated central operator/controller workstation.
# sshnode invokes MU controllers only; each controller uses native authenticated XTP to its MI.
set -euo pipefail
[[ $# -ge 1 ]] || { echo "usage: $0 RUN_ID [--only ed209f ed209h] [--dry-run]" >&2; exit 64; }
RUN=$1;shift
HERE=$(cd "$(dirname "$0")" && pwd)
: "${SSHNODE:=./sshnode.sh}"
: "${CONTROLLER_SCRIPT:=/opt/rexxos/rto2-smoke/bin/mu_controller_run.sh}"
: "${RESULT_DIR:=./ed209-rto2-runs}"
DEST="$RESULT_DIR/$RUN"
exec python3 "$HERE/run_20mi.py" --sshnode "$SSHNODE" --controller-script "$CONTROLLER_SCRIPT" --run "$RUN" --output "$DEST" "$@"
