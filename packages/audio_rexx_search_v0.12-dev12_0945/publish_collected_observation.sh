#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NODE=${1:?node required}
RESULT_DIR=${2:?result directory required}
CATALOG="$RESULT_DIR/candidate_configs.tsv"
PARETO="$RESULT_DIR/pareto_candidates.tsv"
RESULT_JSON="$RESULT_DIR/results.json"
[[ -s "$CATALOG" && -s "$RESULT_JSON" ]] || { echo "SKIP observation: missing result evidence for $NODE" >&2; exit 3; }
case "$NODE" in ed209a|ed209b|ed209c|ed209d|ed209e|ed209i|ed209h) :;; *) echo "invalid node $NODE" >&2; exit 2;; esac
IFS=$'\t' read -r candidate_id lane rank score gain hp lp denoise echo_delay echo_gain cancel_strength cancel_tweak compress compress_ratio compress_threshold reject_bands chain < <(sed -n '2p' "$CATALOG")
[[ -n "$candidate_id" ]] || { echo "SKIP observation: empty candidate catalog for $NODE" >&2; exit 3; }
thread=${AUDIO_POOL_THREAD_ID:-campaign-0945-quality-v1}
OBS_DIR=${AUDIO_POOL_OBSERVATION_DIR:-$ROOT/run/controller/observations}
mkdir -p "$OBS_DIR"

# The scalar-ranked result remains useful historical evidence, but dev6 marks it
# experimental until perceptual calibration.  Publication does not authorize a
# follow-on job; the coordinator must submit an explicit job through admission.
digest=$(sha256sum "$RESULT_JSON" | awk '{print $1}')
msg_id="${NODE}-result-${digest:0:24}"
OBS="$OBS_DIR/$msg_id.obs"
cat > "$OBS" <<E
schema=audio.pool.observation/1
message_id=$msg_id
node_id=$NODE
kind=RESULT
thread_id=$thread
in_reply_to=
candidate_id=$candidate_id
score=$score
summary=${NODE} completed ${lane:-search}; scalar rank ${rank:-1} is experimental pending perceptual calibration and is available for cross-node comparison
evidence_ref=collected_results/${NODE}/results.json
E
"$ROOT/h_api.sh" observe "$OBS"

# Publish the explicit Pareto frontier as a second, independent observation.
# This gives the coordinator/bigger monkey resemblance and artefact trade-offs
# without collapsing them back into hidden scalar weights.
if [[ -s "$PARETO" ]]; then
  mapfile -t front_rows < <(awk -F '\t' 'NR>1 && $5==1 {print $1 "\t" $7 "\t" $8 "\t" $9}' "$PARETO")
  if ((${#front_rows[@]} > 0)); then
    pareto_digest=$(sha256sum "$PARETO" | awk '{print $1}')
    frontier_id="${NODE}-frontier-${pareto_digest:0:24}"
    first_candidate=${front_rows[0]%%$'\t'*}
    front_count=${#front_rows[@]}
    sample=""
    limit=$front_count; (( limit > 3 )) && limit=3
    for ((i=0;i<limit;i++)); do
      IFS=$'\t' read -r cid refdist preover postclip <<<"${front_rows[$i]}"
      token="${cid}[ref=${refdist},pre=${preover},clip=${postclip}]"
      [[ -n "$sample" ]] && sample+="; "
      sample+="$token"
    done
    FOBS="$OBS_DIR/$frontier_id.obs"
    cat > "$FOBS" <<E
schema=audio.pool.observation/1
message_id=$frontier_id
node_id=$NODE
kind=FRONTIER
thread_id=$thread
in_reply_to=$msg_id
candidate_id=$first_candidate
score=
summary=${NODE} Pareto frontier has ${front_count} non-dominated candidate(s); ${sample}
evidence_ref=collected_results/${NODE}/pareto_candidates.tsv
E
    "$ROOT/h_api.sh" observe "$FOBS"
  fi
fi
