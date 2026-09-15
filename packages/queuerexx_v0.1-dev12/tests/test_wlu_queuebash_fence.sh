#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
qid="$(rexx test_wlu_submit_for_queuebash.rex "$tmp")"
job="$(find "$tmp/waiting" -type f -name "$qid.job" -print -quit)"
[[ -n "$job" && -f "$job" ]]
[[ "$job" == "$tmp"/waiting/p*/*.job ]]
grep -q '^WLU_MODE="managed"$' "$job"
grep -q '^JOB_CLASS="QUEUEREXX_WLU_HOLD"$' "$job"
grep -q '^WLU_ORIGINAL_JOB_CLASS="DEFAULT"$' "$job"
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
# QueueBash itself must see the staging class as unavailable.
if _queue_class_available "$job" >/dev/null 2>&1; then
  echo "FAIL QueueBash considered WLU hold class runnable" >&2
  exit 1
fi
# Sentinel and operator reevaluation must not promote it to pending.
_queue_sentinel_recheck_waiting >/dev/null 2>&1 || true
[[ -f "$job" ]]
[[ -z "$(find "$tmp/pending" -type f -name "$qid.job" -print -quit 2>/dev/null || true)" ]]
queue reevaluate "$qid" >/dev/null 2>&1 || true
job2="$(find "$tmp/waiting" -type f -name "$qid.job" -print -quit)"
[[ -n "$job2" && -f "$job2" ]]
[[ -z "$(find "$tmp/pending" -type f -name "$qid.job" -print -quit 2>/dev/null || true)" ]]
# QueueBash must still be able to inspect/source the shared record.
set +u
# shellcheck disable=SC1090
source "$job2"
set -u
[[ "$WLU_MODE" == managed ]]
[[ "$JOB_CLASS" == QUEUEREXX_WLU_HOLD ]]
[[ "$WLU_ORIGINAL_JOB_CLASS" == DEFAULT ]]
queue list --json >/dev/null
printf '%s\n' "PASS QueueBash understands the WLU staging fence and cannot promote the managed job"
