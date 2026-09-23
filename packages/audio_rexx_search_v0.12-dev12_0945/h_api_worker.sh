#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MODE=${1:---loop}
SPOOL=${H_API_SPOOL_ROOT:-$ROOT/state/h-api}
AUDIO_ROOT=${H_AUDIO_ROOT:?set H_AUDIO_ROOT to source recording directory}
POLL=${H_API_WORKER_POLL_SEC:-2}
FSYNC=${AUDIO_SEARCH_FSYNC_HELPER:-$ROOT/foreign/audio_checkpoint_fsync}
LOCK="$SPOOL/.worker.lock"
mkdir -p "$SPOOL"/{pending,active,complete,failed} "$ROOT/input/ed209h/jobs" "$ROOT/results/ed209h/jobs" "$ROOT/run"
command -v flock >/dev/null 2>&1 || { echo 'FAIL: flock required for the single H spool worker' >&2; exit 3; }
exec 9>"$LOCK"
flock -n 9 || { echo "FAIL: another H API worker already owns $LOCK" >&2; exit 7; }

recover_active(){
  local f jobid pending
  shopt -s nullglob
  for f in "$SPOOL"/active/*.job; do
    jobid=$(basename "$f" .job)
    [[ "$jobid" =~ ^[A-Za-z0-9._-]{1,80}$ ]] || continue
    if [[ -e "$SPOOL/complete/$jobid.job" || -e "$SPOOL/failed/$jobid.job" ]]; then
      echo "H_API_RECOVERY_DROP_REDUNDANT_ACTIVE id=$jobid" >&2
      rm -f -- "$f"
      continue
    fi
    pending="$SPOOL/pending/$jobid.job"
    if [[ -e "$pending" ]]; then
      if cmp -s -- "$f" "$pending"; then
        rm -f -- "$f"
        echo "H_API_RECOVERY_DUPLICATE_ACTIVE id=$jobid" >&2
      else
        echo "H_API_RECOVERY_CONFLICT id=$jobid" >&2
        mv -f -- "$f" "$SPOOL/failed/$jobid.job"
        printf '%s\n' 'recovery_conflict=active_and_pending_differ' > "$SPOOL/failed/$jobid.reason"
      fi
      continue
    fi
    mv -f -- "$f" "$pending"
    [[ -x "$FSYNC" ]] && "$FSYNC" "$pending" || true
    echo "H_API_RECOVERY_REQUEUED id=$jobid" >&2
  done
  shopt -u nullglob
}

process_one(){
  local pending jobid active input out reason result rc
  pending=$(find "$SPOOL/pending" -maxdepth 1 -type f -name '*.job' -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | cut -d' ' -f2- || true)
  [[ -n "$pending" ]] || return 1
  jobid=$(basename "$pending" .job)
  if [[ ! "$jobid" =~ ^[A-Za-z0-9._-]{1,80}$ ]]; then
    reason="invalid_job_filename=$(basename -- "$pending")"
    printf '%s\n' "$reason" > "$SPOOL/failed/INVALID.reason"
    mv -f -- "$pending" "$SPOOL/failed/INVALID.job"
    [[ -x "$FSYNC" ]] && "$FSYNC" "$SPOOL/failed/INVALID.job" "$SPOOL/failed/INVALID.reason" || true
    return 0
  fi
  active="$SPOOL/active/$jobid.job"
  mv -f -- "$pending" "$active" || return 1
  [[ -x "$FSYNC" ]] && "$FSYNC" "$active" || true
  input="$ROOT/input/ed209h/jobs/$jobid"
  out="$ROOT/results/ed209h/jobs/$jobid"
  rm -rf "$input" "$out"; mkdir -p "$out"
  echo "H_API_JOB_START id=$jobid" >&2
  set +e
  "$ROOT/materialize_h_api_job.sh" "$active" "$input" "$AUDIO_ROOT" >"$ROOT/run/$jobid.materialize.log" 2>&1
  rc=$?
  if (( rc==0 )); then
    H_INPUT_DIR="$input" H_OUTPUT_DIR="$out" H_JOB_ID="$jobid" H_CONTROL_JOB="$active" \
      "$ROOT/h_refinement_worker.sh" ed209h >"$ROOT/run/$jobid.refine.log" 2>&1
    rc=$?
  fi
  set -e
  if (( rc==0 )); then
    result="results/ed209h/jobs/$jobid"
    printf '%s\n' "$result" > "$SPOOL/complete/$jobid.result"
    mv -f -- "$active" "$SPOOL/complete/$jobid.job"
    [[ -x "$FSYNC" ]] && "$FSYNC" "$SPOOL/complete/$jobid.job" "$SPOOL/complete/$jobid.result" || true
    echo "H_API_JOB_COMPLETE id=$jobid result=$result" >&2
  else
    reason="worker_rc=$rc materialize_log=run/$jobid.materialize.log refine_log=run/$jobid.refine.log"
    printf '%s\n' "$reason" > "$SPOOL/failed/$jobid.reason"
    mv -f -- "$active" "$SPOOL/failed/$jobid.job"
    [[ -x "$FSYNC" ]] && "$FSYNC" "$SPOOL/failed/$jobid.job" "$SPOOL/failed/$jobid.reason" || true
    echo "H_API_JOB_FAILED id=$jobid rc=$rc" >&2
  fi
  return 0
}

recover_active
case "$MODE" in
  --once) process_one || true ;;
  --loop)
    echo "H_API_WORKER_READY node=ed209h spool=$SPOOL audio_root=$AUDIO_ROOT"
    while :; do process_one || sleep "$POLL"; done
    ;;
  *) echo 'usage: h_api_worker.sh --loop|--once' >&2; exit 2;;
esac
