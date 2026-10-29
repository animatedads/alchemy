#!/bin/sh
# Run ooTest groups against mutants, in parallel. A mutant is KILLED when the group reports a failure
# or an error, TIMEOUT when it runs past the limit (counted as killed), SURVIVED when every test passes.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-29.
# Args: jobs file, ooTest root, output file, parallel workers (default 4), seconds per group (default 20)
set -eu
JOBS=$1; OT=$2; OUT=$3; P=${4:-4}; LIMIT=${5:-20}
export OT LIMIT
export REXX_PATH="$OT:$OT/framework${REXX_PATH:+:$REXX_PATH}"
: > "$OUT"
tr '\t' '\037' < "$JOBS" | xargs -d '\n' -P "$P" -I{} sh -c '
  IFS=$(printf "\037"); set -- $1
  out=$(SLAM_UNDER_TEST="$2" timeout -s KILL "$LIMIT" rexx "$1" 2>&1) && rc=0 || rc=$?
  f=$(printf "%s\n" "$out" | awk "/^Failures:/{print \$2}")
  e=$(printf "%s\n" "$out" | awk "/^Errors:/{print \$2}")
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then v=TIMEOUT
  elif [ "$f" = 0 ] && [ "$e" = 0 ]; then v=SURVIVED
  elif [ -n "$f" ]; then v=KILLED
  else v=CRASHED
  fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$3" "$4" "$5" "$v" "$6"
' _ {} >> "$OUT"
