#!/bin/sh
# Every mutant against SLAM's cases and against the random cases, one process each, with a time limit.
# KILLED: a case's outcome differs. SURVIVED: none does. TIMEOUT: still running at the limit (killed).
# Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-29.
# Args: jobs file (from mutate.rex) | cases file | output file | seconds (default 15) | workers (default 2)
set -eu
JOBS=$1; CASES=$2; OUT=$3; LIMIT=${4:-15}; P=${5:-2}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export CASES LIMIT HERE
: > "$OUT"
tr '\t' '\037' < "$JOBS" | xargs -d '\n' -P "$P" -I{} sh -c '
  IFS=$(printf "\037"); set -- $1
  v=$(timeout -s KILL "$LIMIT" rexx "$HERE/mutant_runner.rex" "$CASES|$3|$2|$5" 2>&1) && rc=0 || rc=$?
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then v=TIMEOUT; fi
  printf "%s\t%s\t%s\t%s\t%s\n" "$3" "$4" "$5" "$(printf "%s" "$v" | head -n 1)" "$6"
' _ {} >> "$OUT"
