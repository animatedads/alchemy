#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
out="$(queue submit qb-wlu-bridge --runner direct -- /bin/true)"
qid="$(printf '%s\n' "$out" | awk '/^Submitted /{print $2; exit}')"
[[ -n "$qid" ]]
pending="$(find "$tmp/pending" -type f -name "$qid.job" -print -quit)"
[[ -n "$pending" && -f "$pending" ]]
rexx test_wlu_bridge_queuebash_job.rex "$tmp" "$qid" >/dev/null
[[ -z "$(find "$tmp/pending" -type f -name "$qid.job" -print -quit 2>/dev/null || true)" ]]
job="$(find "$tmp/waiting" -type f -name "$qid.job" -print -quit)"
[[ -n "$job" && -f "$job" ]]
[[ "$job" == "$tmp"/waiting/p*/*.job ]]
set +u
# shellcheck disable=SC1090
source "$job"
set -u
[[ "$JOB_CLASS" == QUEUEREXX_WLU_HOLD ]]
[[ "$WLU_ORIGINAL_JOB_CLASS" == DEFAULT ]]
[[ "$WLU_MODE" == managed ]]
[[ "$WLU_EXPECTED_MICRO_WLU" == 2000000 ]]
[[ "$WLU_CEILING_MICRO_WLU" == 3000000 ]]
[[ "$WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND" == 500000 ]]
if _queue_class_available "$job" >/dev/null 2>&1; then
  echo "FAIL QueueBash considered bridged WLU job runnable" >&2
  exit 1
fi
_queue_sentinel_recheck_waiting >/dev/null 2>&1 || true
queue reevaluate "$qid" >/dev/null 2>&1 || true
[[ -n "$(find "$tmp/waiting" -type f -name "$qid.job" -print -quit)" ]]
[[ -z "$(find "$tmp/pending" -type f -name "$qid.job" -print -quit 2>/dev/null || true)" ]]
qb_json="$(queue list --json)"
python3 - "$qid" "$qb_json" <<'PY'
import json,sys
qid=sys.argv[1]; d=json.loads(sys.argv[2])
m=[j for j in d.get('jobs',[]) if j.get('qid')==qid]
assert len(m)==1 and m[0].get('state')=='waiting',m
assert m[0].get('class')=='QUEUEREXX_WLU_HOLD',m
print('PASS real QueueBash pending job safely adopted into QueueRexx WLU staging')
PY
