#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
COLLECTED=${1:-$ROOT/collected_results}; RANK_SPEC=${2:-rank_01.wav}; JOB=${3:-$ROOT/run/controller/h-api-job-0945.txt}
export H_JOB_ID=${H_JOB_ID:-h-0945-quality-v1-$(date -u +%Y%m%dT%H%M%SZ)}
if [[ ${H_NO_AUDIO_STAGE:-0} != 1 ]]; then "$ROOT/stage_h_campaign_audio.sh"; fi
"$ROOT/prepare_h_api_job.sh" "$COLLECTED" "$RANK_SPEC" "$JOB"
"$ROOT/h_api.sh" submit "$JOB"
echo "H_JOB_ID=$H_JOB_ID"
echo "STATUS: $ROOT/h_api.sh status $H_JOB_ID"
