#!/usr/bin/env bash
set -euo pipefail
root="$(mktemp -d)"
trap 'kill "${p1:-}" "${p2:-}" 2>/dev/null || true; rm -rf "$root"' EXIT
mkdir -p "$root"/{pending,waiting,running,paused,done,failed,pol_blocked,interrupted,cancelled,deleted,logs,workers,outputs,streams,locks/state,logs/queue-state-reconcile}
sleep 30 & p1=$!
sleep 30 & p2=$!
pg1="$(ps -o pgid= -p "$p1" | tr -d ' ')"
pg2="$(ps -o pgid= -p "$p2" | tr -d ' ')"
cat > "$root/running/ri.job" <<JOB
JOB_ID=ri
JOB_NAME=ri
PRIORITY=10
RUNNER_USED=direct
RUN_PID=$p1
RUN_PGID=$pg1
RUN_STARTED_AT=2026-09-13T20:00:00+01:00
COMMAND=( sleep 30 )
JOB
cat > "$root/interrupted/ri.job" <<'JOB'
JOB_ID=ri
JOB_NAME=ri
PRIORITY=10
INTERRUPTED_REASON=stale-running-detected-by-health
COMMAND=( sleep 30 )
JOB
cat > "$root/running/rp.job" <<JOB
JOB_ID=rp
JOB_NAME=rp
PRIORITY=10
RUNNER_USED=direct
RUN_PID=$p2
RUN_PGID=$pg2
RUN_STARTED_AT=2026-09-13T20:00:00+01:00
COMMAND=( sleep 30 )
JOB
cat > "$root/pol_blocked/rp.job" <<'JOB'
JOB_ID=rp
JOB_NAME=rp
PRIORITY=10
POLICY_BLOCKED_REASON='job file not found'
COMMAND=( sleep 30 )
JOB
cat > "$root/interrupted/ip.job" <<'JOB'
JOB_ID=ip
JOB_NAME=ip
PRIORITY=10
INTERRUPTED_REASON=stale-running-detected-by-health
COMMAND=( true )
JOB
cat > "$root/pol_blocked/ip.job" <<'JOB'
JOB_ID=ip
JOB_NAME=ip
PRIORITY=10
POLICY_BLOCKED_REASON='job file not found'
COMMAND=( true )
JOB
QREXX_DIAG_ROOT="$root" rexx test_diagnosis.rex
QUEUEBASH_ROOT="$root" rexx ../bin/queuerexx.rex diagnose ri --json | grep -q '"diagnosis":"running_interrupted"'
[[ -f "$root/interrupted/ri.job" ]] # diagnose must not mutate
[[ -f "$root/running/ri.job" ]]
echo 'PASS diagnose CLI non-mutating'
