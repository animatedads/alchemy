#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
NODE=${1:-ed209h}
[[ "$NODE" == ed209h ]] || { echo "FAIL: H refinement worker only accepts ed209h" >&2; exit 2; }
JOB="$ROOT/jobs/ed209h.conf"
INPUT=${H_INPUT_DIR:-$ROOT/input/ed209h}
MANIFEST="$INPUT/inputs.tsv"
WINDOWS="$INPUT/windows/windows.tsv"
PLAN=${H_BAND_PLAN_FILE:-$ROOT/jobs/ed209h_band_plans.txt}
OUT=${H_OUTPUT_DIR:-$ROOT/results/ed209h}
JOB_ID=${H_JOB_ID:-manual}
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
REXX_BIN=${REXX_BIN:-$OOREXX_PREFIX/bin/rexx}
[[ -x "$REXX_BIN" ]] || { echo "FAIL: ooRexx rexx not found at $REXX_BIN" >&2; exit 3; }
"$REXX_BIN" -v 2>&1 | grep -q 'Open Object Rexx Version 5.3.0 r13196' || { echo 'FAIL: exact ooRexx 5.3.0 r13196 required' >&2; exit 3; }
[[ -s "$MANIFEST" && -s "$WINDOWS" && -s "$INPUT/INPUTS.sha256" ]] || { echo 'FAIL: incomplete H rolling input package' >&2; exit 4; }
(cd "$INPUT" && sha256sum -c INPUTS.sha256 >/dev/null) || { echo 'FAIL: H rolling input integrity mismatch' >&2; exit 4; }

jobv(){ awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$JOB"; }
CONTROL=${H_CONTROL_JOB:-}
controlv(){ awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$CONTROL"; }
value_or_job(){
  local k=$1 v=''
  if [[ -n "$CONTROL" && -s "$CONTROL" ]]; then v=$(controlv "$k"); fi
  [[ -n "$v" ]] && printf '%s\n' "$v" || jobv "$k"
}
budget_gib=$(value_or_job workspace_budget_gib); min_mib=$(jobv memory_total_min_mib); shortlist=$(value_or_job shortlist_count)
radius=$(value_or_job temporal_radius_sec); window_duration=$(value_or_job window_duration_sec); step=$(value_or_job window_step_sec); overlap=$(value_or_job window_overlap_sec)
node_budget_cap=$(jobv workspace_budget_gib); node_radius_cap=$(jobv temporal_radius_sec); node_window_cap=$(jobv window_duration_sec); api_shortlist_cap=$(jobv api_max_shortlist_count)
mix_enabled=$(jobv voice_mix_enabled); mix_depth=$(jobv voice_mix_pool_depth); mix_min_att=$(jobv voice_mix_min_attenuation_db); mix_primary_gain=$(jobv voice_mix_primary_gain); mix_residual_gain=$(jobv voice_mix_residual_gain)
[[ -n "$api_shortlist_cap" ]] || api_shortlist_cap=64
[[ -n "$mix_enabled" ]] || mix_enabled=1
[[ -n "$mix_depth" ]] || mix_depth=24
[[ -n "$mix_min_att" ]] || mix_min_att=0
[[ -n "$mix_primary_gain" ]] || mix_primary_gain=1
[[ -n "$mix_residual_gain" ]] || mix_residual_gain=1
for v in "$budget_gib" "$min_mib" "$shortlist" "$radius" "$window_duration" "$step" "$overlap" "$node_budget_cap" "$node_radius_cap" "$node_window_cap" "$api_shortlist_cap" "$mix_enabled" "$mix_depth"; do [[ "$v" =~ ^[0-9]+$ ]] || { echo 'FAIL: H policy values must be unsigned integers' >&2; exit 4; }; done
for v in "$mix_min_att" "$mix_primary_gain" "$mix_residual_gain"; do [[ "$v" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo 'FAIL: H voice mix attenuation/gains must be non-negative numbers' >&2; exit 4; }; done
(( mix_depth>=2 && mix_depth<=64 )) || { echo 'FAIL: H voice mix pool depth must be 2..64' >&2; exit 4; }
(( budget_gib>=1 && budget_gib<=node_budget_cap && shortlist>=1 && shortlist<=api_shortlist_cap && radius<=node_radius_cap && window_duration>=30 && window_duration<=node_window_cap && step>=10 && step<=window_duration && overlap==window_duration-step )) || { echo 'FAIL: invalid H refinement policy or requested policy exceeds node capability' >&2; exit 4; }
budget_bytes=$(awk -v g="$budget_gib" 'BEGIN { printf "%.0f", g*1073741824 }')
free_bytes=$(df -PB1 "$ROOT" | awk 'NR==2 {print $4}')
need_bytes=$((budget_bytes + 2147483648))
(( free_bytes >= need_bytes )) || { echo "FAIL: ed209h free disk $free_bytes below ${budget_gib} GiB workspace + 2 GiB reserve" >&2; exit 6; }
mem_total_mib=$(awk '/^MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo)
(( mem_total_mib >= min_mib )) || { echo "FAIL: ed209h total memory ${mem_total_mib} MiB below required ${min_mib} MiB" >&2; exit 6; }
parents=$(( $(wc -l < "$MANIFEST") - 1 )); windows=$(( $(wc -l < "$WINDOWS") - 1 ))
(( parents > 0 && windows > 0 )) || { echo 'FAIL: H requires at least one parent and one rolling window' >&2; exit 4; }
first_source=$(awk -F '\t' 'NR==2{print $7}' "$WINDOWS")
source_bytes=$(stat -c %s "$INPUT/windows/$first_source")
extra_mix_files=0; (( mix_enabled != 0 )) && extra_mix_files=2
estimate=$(( parents * windows * (shortlist + 1 + extra_mix_files) * source_bytes + 64*1024*1024 ))
(( estimate <= budget_bytes )) || { echo "FAIL: H selected parent/window shortlist estimate $estimate exceeds workspace budget $budget_bytes; reduce promoted ranks or shortlist" >&2; exit 6; }
echo "H PREFLIGHT node=ed209h free_bytes=$free_bytes workspace_budget_gib=$budget_gib reserve_gib=2 memory_total_mib=$mem_total_mib parents=$parents windows=$windows estimated_retained_bytes=$estimate"

"$ROOT/ensure_native_runtime.sh"
export REXX_PATH="$ROOT/lib:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
corpus="$ROOT/reference/QUALITY_CORPUS.tsv"
bridge="$ROOT/foreign/audio-search-native.bridge.json"
rm -rf "$OUT"; mkdir -p "$OUT" "$ROOT/run/h-window-configs"
summary="$OUT/H_TEMPORAL_SUMMARY.tsv"
printf 'parent_node\tparent_rank\tparent_candidate_id\twindow_id\trelative_offset_sec\tsource_start_sec\tcompanion_start_sec\tbaseline_score\tbest_score\tbest_added_reject_bands\tresult_dir\n' > "$summary"
review="$OUT/review_candidates.tsv"
printf 'candidate_id\tlane_id\trank\tscore\tmaterial_ref\tpcm_hash64\tobjective_id\tchain\n' > "$review"
voice_mix="$OUT/H_VOICE_MIX.tsv"
printf 'parent_node\tparent_rank\tparent_candidate_id\twindow_id\trelative_offset_sec\toutput\tprimary_rank\tresidual_rank\tprimary_rms_db\tresidual_rms_db\tattenuation_db\tminimum_attenuation_db\tparent_cancel_strength\tresidual_added_reject_bands\tmix_score\tpcm_hash64\tfallback_quietest\tresult_dir\n' > "$voice_mix"
export AUDIO_H_VOICE_MIX_ENABLED="$mix_enabled"
export AUDIO_H_VOICE_MIX_POOL_DEPTH="$mix_depth"
export AUDIO_H_VOICE_MIX_MIN_ATTENUATION_DB="$mix_min_att"
export AUDIO_H_VOICE_MIX_PRIMARY_GAIN="$mix_primary_gain"
export AUDIO_H_VOICE_MIX_RESIDUAL_GAIN="$mix_residual_gain"
export AUDIO_QUALITY_TARGET_SET="$(jobv quality_target_set)"
export AUDIO_QUALITY_CORPUS="$(jobv quality_corpus)"
export AUDIO_QUALITY_TARGET_COUNT="$(jobv quality_target_count)"

processed=0
while IFS=$'\t' read -r parent_node parent_rank parent_id config_file; do
  [[ "$parent_node" == parent_node ]] && continue
  [[ -n "$parent_node" && -n "$parent_rank" && -n "$parent_id" && -n "$config_file" ]] || { echo 'FAIL: malformed H parent input row' >&2; exit 4; }
  [[ "$config_file" != /* && "$config_file" != *..* ]] || { echo "FAIL: unsafe H config path $config_file" >&2; exit 4; }
  pconf="$INPUT/$config_file"; [[ -s "$pconf" ]] || { echo "FAIL: missing H parent config $pconf" >&2; exit 4; }
  ptag=$(printf '%s_rank_%02d' "$parent_node" "$parent_rank" | tr -cs 'A-Za-z0-9._-' '_')
  while IFS=$'\t' read -r window_id offset source_start source_duration companion_start companion_duration source_file companion_file; do
    [[ "$window_id" == window_id ]] && continue
    for f in "$source_file" "$companion_file"; do [[ "$f" != */* && "$f" != *..* ]] || { echo "FAIL: unsafe H rolling filename $f" >&2; exit 4; }; done
    src="$INPUT/windows/$source_file"; comp="$INPUT/windows/$companion_file"
    [[ -s "$src" && -s "$comp" ]] || { echo "FAIL: missing H rolling WAV for $window_id" >&2; exit 4; }
    wconf="$ROOT/run/h-window-configs/${window_id}.conf"
    cat > "$wconf" <<EOF
window_id=$window_id
relative_offset_sec=$offset
source_start_sec=$source_start
source_duration_sec=$source_duration
companion_start_sec=$companion_start
companion_duration_sec=$companion_duration
EOF
    target="$OUT/${ptag}__${window_id}"
    mkdir -p "$target"
    AUDIO_BAND_PLAN_FILE="$PLAN" "$REXX_BIN" "$ROOT/bin/AudioTemporalBandRefinement.rex" \
      "$src" "$comp" "$corpus" "$target" "$bridge" "$pconf" "$wconf" "$shortlist"
    baseline_score=$(sed -n 's/.*"baseline_score": \([^,}]*\).*/\1/p' "$target/temporal_band_results.json" | head -1)
    first=$(grep -m1 '^[[:space:]]*{"rank": 1,' "$target/temporal_band_results.json" || true)
    best_score=$(printf '%s\n' "$first" | sed -n 's/.*"score": \([^,}]*\).*/\1/p')
    best_band=$(printf '%s\n' "$first" | sed -n 's/.*"added_reject_bands": "\([^"]*\)".*/\1/p')
    rel="${ptag}__${window_id}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$parent_node" "$parent_rank" "$parent_id" "$window_id" "$offset" "$source_start" "$companion_start" "$baseline_score" "$best_score" "$best_band" "$rel" >> "$summary"
    awk -F '\t' -v OFS='\t' -v p="$rel/" 'NR>1{$5=p $5; print}' "$target/review_candidates.tsv" >> "$review"
    if [[ -s "$target/voice_mix.tsv" ]] && (( $(wc -l < "$target/voice_mix.tsv") > 1 )); then
      awk -F '\t' -v OFS='\t' -v pn="$parent_node" -v pr="$parent_rank" -v pid="$parent_id" -v rel="$rel" 'NR>1{print pn,pr,pid,$2,$3,rel"/"$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,rel}' "$target/voice_mix.tsv" >> "$voice_mix"
    fi
    processed=$((processed+1))
  done < "$WINDOWS"
done < "$MANIFEST"
(( processed == parents*windows )) || { echo "FAIL: H processed=$processed expected=$((parents*windows))" >&2; exit 7; }

{ head -1 "$summary"; tail -n +2 "$summary" | sort -t $'\t' -k9,9g -k3,3 -k5,5n; } > "$OUT/H_BEST_WINDOWS.tsv"
retained=$(du -sb "$OUT" | awk '{print $1}')
(( retained <= budget_bytes )) || { echo "FAIL: H retained output $retained exceeds workspace $budget_bytes" >&2; exit 7; }
cat > "$OUT/H_EVIDENCE.txt" <<EOF
node=ed209h
strategy=H
job_id=$JOB_ID
provider=vultr
region=atlanta
role=voice-frontier-temporal-pursuit-and-multiband-refinement
strong_parent_count=$parents
temporal_window_count=$windows
parent_window_cross_product=$processed
temporal_radius_sec=$radius
window_duration_sec=$window_duration
window_step_sec=$step
window_overlap_sec=$overlap
parent_chain_replay=true
companion_alignment_recomputed_per_window=true
workspace_budget_gib=$budget_gib
estimated_retained_output_bytes=$estimate
retained_output_bytes=$retained
additive_voice_mix_enabled=$mix_enabled
additive_voice_mix_pool_depth=$mix_depth
additive_voice_mix_min_attenuation_db=$mix_min_att
additive_voice_mix_primary_gain=$mix_primary_gain
additive_voice_mix_residual_gain=$mix_residual_gain
additive_voice_mix_semantics=rank1-plus-quietest-top24-residual-with-final-soft-limiter-no-normalization
objective_status=UNQUALIFIED_PENDING_HUMAN_REVIEW
EOF
(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
mix_count=$(( $(wc -l < "$voice_mix") - 1 )); echo "PASS H ROLLING REFINEMENT parents=$parents windows=$windows parent_window_pairs=$processed voice_mixes=$mix_count retained_bytes=$retained"
