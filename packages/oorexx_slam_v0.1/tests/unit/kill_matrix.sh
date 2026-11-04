#!/bin/sh
# Leg Drop, first step: the kill matrix. Every mutant against every case of a suite (not only up to the
# first case that catches it), so each rule's cases can be scored on their own: what they catch, and
# what only they catch. run_mutants.sh stops at the first case, which credits HAPPY (case 1) with most kills.
# Architecture: Tom Dyer (Leg Drop: proposed by the rx2cpp lane, Claude (Opus 5.5)). Code: Claude (Opus 5.5), 2026-10-30.
# Args: jobs file (from mutate.rex) | cases file | output file | seconds (default 30) | workers (default 2)
# Output, one line per job: unit TAB mutant TAB suite TAB status TAB cases that catch it TAB the change
#   status: KILLED, SURVIVED, NOCOMPILE, or TIMEOUT (the cases listed are those that caught it before the limit)
set -eu
JOBS=$1; CASES=$2; OUT=$3; LIMIT=${4:-30}; P=${5:-2}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export CASES LIMIT HERE
: > "$OUT"
tr '\t' '\037' < "$JOBS" | xargs -d '\n' -P "$P" -I{} sh -c '
  IFS=$(printf "\037"); set -- $1
  v=$(timeout -s KILL "$LIMIT" rexx "$HERE/mutant_runner.rex" "$CASES|$3|$2|$5|ALL" 2>&1) && rc=0 || rc=$?
  kills=$(printf "%s\n" "$v" | awk "/^KILL /{printf \"%s \", \$2}")
  if printf "%s\n" "$v" | grep -q "does-not-compile"; then st=NOCOMPILE
  elif [ "$rc" = 124 ] || [ "$rc" = 137 ]; then st=TIMEOUT
  elif printf "%s\n" "$v" | grep -q "^END "; then if [ -n "$kills" ]; then st=KILLED; else st=SURVIVED; fi
  else st=TIMEOUT
  fi
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$3" "$4" "$5" "$st" "$kills" "$6"
' _ {} >> "$OUT"
