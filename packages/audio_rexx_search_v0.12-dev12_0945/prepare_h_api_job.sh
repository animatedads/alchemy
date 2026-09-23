#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTED=${1:-$ROOT/collected_results}
RANK_SPEC=${2:-rank_01.wav}
OUT=${3:-$ROOT/run/controller/h-api-job.txt}
JOB_ID=${H_JOB_ID:-h-$(date -u +%Y%m%dT%H%M%SZ)-$$}
BASE_JOB=${H_BASE_JOB:-$ROOT/jobs/ed209a.conf}
jobv(){ awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$BASE_JOB"; }
source_rec=$(jobv source_recording); companion_rec=$(jobv companion_recording)
source_start=$(jobv source_start_sec); companion_start=$(jobv companion_start_sec); companion_duration=$(jobv companion_duration_sec)
[[ -n "$source_rec" && -n "$companion_rec" && $source_start =~ ^[0-9]+$ && $companion_start =~ ^[0-9]+$ && $companion_duration =~ ^[0-9]+$ ]] || { echo 'FAIL: base A job lacks recording/timing metadata' >&2; exit 3; }
[[ "$JOB_ID" =~ ^[A-Za-z0-9._-]{1,80}$ ]] || { echo 'FAIL: H_JOB_ID must be 1..80 safe characters' >&2; exit 2; }
mkdir -p "$(dirname -- "$OUT")"
tmp="$OUT.tmp.$$"
{
  echo 'schema=audio.h.refinement.control/2'
  echo "job_id=$JOB_ID"
  echo "source_recording=$source_rec"
  echo "source_start_sec=$source_start"
  echo "companion_recording=$companion_rec"
  echo "companion_start_sec=$companion_start"
  echo "companion_duration_sec=$companion_duration"
  echo 'temporal_radius_sec=180'
  echo 'window_duration_sec=180'
  echo 'window_step_sec=90'
  echo 'window_overlap_sec=90'
  echo 'shortlist_count=16'
  echo 'workspace_budget_gib=10'
} > "$tmp"

count=0
IFS=',' read -r -a ranks <<<"$RANK_SPEC"
for node in ed209a ed209b ed209c ed209d ed209e ed209i; do
  cfgcat="$COLLECTED/$node/candidate_configs.tsv"
  [[ -s "$cfgcat" ]] || continue
  for rankfile in "${ranks[@]}"; do
    rankfile=${rankfile// /}
    [[ "$rankfile" =~ ^rank_([0-9]+)\.wav$ ]] || { echo "FAIL: rank selector must look like rank_01.wav: $rankfile" >&2; rm -f "$tmp"; exit 2; }
    rank=$((10#${BASH_REMATCH[1]}))
    [[ -s "$COLLECTED/$node/$rankfile" ]] || continue
    row=$(awk -F '\t' -v r="$rank" 'NR>1 && ($3+0)==r {print; exit}' "$cfgcat")
    [[ -n "$row" ]] || { echo "FAIL: rank $rank missing from $cfgcat" >&2; rm -f "$tmp"; exit 4; }
    # Fail closed before parsing. candidate_configs.tsv has exactly 17 columns;
    # empty fields are semantically meaningful and must remain positional.
    column_count=$(awk -F '\t' '{print NF}' <<<"$row")
    [[ "$column_count" -eq 17 ]] || { echo "FAIL: invalid candidate TSV column count: $column_count expected=17 file=$cfgcat rank=$rank" >&2; rm -f "$tmp"; exit 4; }
    count=$((count+1)); p="parent.$count"
    # Bash treats tab as IFS whitespace and collapses adjacent tabs, which destroys
    # empty TSV columns (notably reject_bands). Convert to a non-whitespace
    # delimiter first so empty fields retain their position in the H envelope.
    row_pipe=${row//$'\t'/|}
    IFS='|' read -r cid lane rr score gain hp lp nf ed eg cs ct co cr th rb chain <<<"$row_pipe"
    {
      echo "$p.node=$node"
      echo "$p.rank=$rank"
      echo "$p.candidate_id=$cid"
      echo "$p.score=$score"
      echo "$p.gain_db=$gain"
      echo "$p.highpass_hz=$hp"
      echo "$p.lowpass_hz=$lp"
      echo "$p.denoise_floor_db=$nf"
      echo "$p.echo_delay_ms=$ed"
      echo "$p.echo_gain=$eg"
      echo "$p.cancel_strength=$cs"
      echo "$p.cancel_tweak_ms=$ct"
      echo "$p.compress=$co"
      echo "$p.compress_ratio=$cr"
      echo "$p.compress_threshold_db=$th"
      echo "$p.reject_bands=$rb"
      echo "$p.chain=$chain"
    } >> "$tmp"
  done
done
(( count>0 )) || { echo "FAIL: no promoted candidate configs found for $RANK_SPEC under $COLLECTED" >&2; rm -f "$tmp"; exit 4; }
echo "parent_count=$count" >> "$tmp"
mv -f "$tmp" "$OUT"
sha256sum "$OUT" > "$OUT.sha256"
echo "PREPARED H API JOB id=$JOB_ID parents=$count rank_spec=$RANK_SPEC file=$OUT"
