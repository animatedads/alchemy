#!/usr/bin/env bash
set -euo pipefail
QB_ROOT="${QUEUEREXX_QUEUEBASH_144_ROOT:?set QUEUEREXX_QUEUEBASH_144_ROOT}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QUEUEBASH_ROOT="$tmp" QUEUEBASH_ALLOW_NONINTERACTIVE=1
# shellcheck source=/dev/null
source "$QB_ROOT/queuebash.sh" >/dev/null
out="$(queue submit mixjob -- /bin/true)"
qid="$(printf '%s\n' "$out" | awk '/^Submitted /{print $2; exit}')"
[[ -n "$qid" ]]
rexx test_mixed_transition.rex "$tmp" "$qid"
json="$(queue list --json)"
python3 - "$qid" "$json" <<'PY'
import json,sys
qid=sys.argv[1]; obj=json.loads(sys.argv[2])
jobs=obj.get('jobs',[])
match=[j for j in jobs if j.get('qid')==qid]
assert len(match)==1, (qid, match)
assert match[0].get('state')=='running', match[0]
print('PASS QueueBash sees QueueRexx running state')
PY
# QueueBash must also respect a QueueRexx-held lock.
cat > "$tmp/hold_lock.rex" <<'REXX'
parse arg root qid
h=.QueueStateLockManager~new(root)~acquire(qid,"mixed-lock-holder",0)
if h==.nil then exit 2
say "LOCKED"
call SysSleep 2
h~release
::requires "QueueRexxMutation.cls"
REXX
REXX_PATH="../src${REXX_PATH:+:$REXX_PATH}" rexx "$tmp/hold_lock.rex" "$tmp" "$qid" >"$tmp/holder.out" &
holder=$!
for _ in $(seq 1 50); do grep -q LOCKED "$tmp/holder.out" 2>/dev/null && break; sleep .02; done
set +e
QUEUEBASH_LOCK_ACTOR=mixed-bash-probe _queue_state_lock_acquire "$qid" "$tmp" 0 >/dev/null 2>&1
lock_rc=$?
set -e
[[ "$lock_rc" -ne 0 ]]
wait "$holder"
echo "PASS QueueBash respects QueueRexx state lock"

# Reverse direction: QueueRexx must not reclaim a live QueueBash lock.
(
  QUEUEBASH_LOCK_ACTOR=mixed-bash-holder
  l="$(_queue_state_lock_acquire "$qid" "$tmp" 0)" || exit 2
  echo LOCKED >"$tmp/bash-holder.out"
  sleep 2
  _queue_state_lock_release "$l"
) &
bash_holder=$!
for _ in $(seq 1 50); do [[ -f "$tmp/bash-holder.out" ]] && break; sleep .02; done
rexx test_try_lock.rex "$tmp" "$qid" blocked
wait "$bash_holder"

# Real mixed-engine claim race. Exactly one implementation may own the move.
race_out="$(queue submit racejob -- /bin/true)"
race_qid="$(printf '%s\n' "$race_out" | awk '/^Submitted /{print $2; exit}')"
race_job="$(find "$tmp/pending" -type f -name "$race_qid.job" -print -quit)"
race_running="$tmp/running/$race_qid.job"
set +e
(_queue_move_pending_to_running "$race_job" "$race_running" "$race_qid" mixed-race) &
bp=$!
rexx test_race_transition.rex "$tmp" "$race_qid" >"$tmp/rexx-race.out" 2>&1 &
rp=$!
wait "$bp"; brc=$?
wait "$rp"; rrc=$?
set -e
cat "$tmp/rexx-race.out"
[[ "$rrc" -eq 0 ]]
[[ -f "$race_running" ]]
[[ ! -e "$race_job" ]]
count="$(find "$tmp" -type f -name "$race_qid.job" | wc -l | tr -d ' ')"
[[ "$count" -eq 1 ]]
echo "PASS mixed QueueBash/QueueRexx claim race leaves exactly one live state (bash_rc=$brc)"

# Reverse ownership order: QueueRexx commits first; QueueBash must then report its normal lost race.
race2_out="$(queue submit racejob2 -- /bin/true)"
race2_qid="$(printf '%s\n' "$race2_out" | awk '/^Submitted /{print $2; exit}')"
race2_job="$(find "$tmp/pending" -type f -name "$race2_qid.job" -print -quit)"
race2_running="$tmp/running/$race2_qid.job"
rexx test_race_transition.rex "$tmp" "$race2_qid" >"$tmp/rexx-race2.out"
cat "$tmp/rexx-race2.out"
grep -q 'RACE_REXX=won' "$tmp/rexx-race2.out"
set +e
_queue_move_pending_to_running "$race2_job" "$race2_running" "$race2_qid" mixed-race2
brc2=$?
set -e
[[ "$brc2" -ne 0 ]]
[[ -f "$race2_running" ]]
[[ ! -e "$race2_job" ]]
count2="$(find "$tmp" -type f -name "$race2_qid.job" | wc -l | tr -d ' ')"
[[ "$count2" -eq 1 ]]
echo "PASS reverse claim order: QueueRexx wins, QueueBash reports lost race"
