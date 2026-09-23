#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_PREFIX=${OOREXX_PREFIX:-/usr/local}
REXX_BIN=${REXX_BIN:-$OOREXX_PREFIX/bin/rexx}
[[ -x "$REXX_BIN" ]] || { echo "FAIL: set REXX_BIN to ooRexx 5.3.0 r13196" >&2; exit 2; }
"$REXX_BIN" -v 2>&1 | grep -q 'Open Object Rexx Version 5.3.0 r13196' || { echo 'FAIL: exact ooRexx 5.3.0 r13196 required' >&2; exit 2; }
"$ROOT/ensure_native_runtime.sh"
command -v ffmpeg >/dev/null 2>&1 || { echo 'FAIL: ffmpeg required only for synthetic test fixture creation' >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo 'FAIL: jq required for qualification JSON assertions' >&2; exit 2; }
TMP="$ROOT/tests/work"; rm -rf "$TMP"; mkdir -p "$TMP"
ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=700:sample_rate=16000:duration=2' -ac 1 -c:a pcm_s16le "$TMP/source.wav"
ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=700:sample_rate=16000:duration=3' -ac 1 -c:a pcm_s16le "$TMP/companion.wav"
cat > "$TMP/a.conf" <<'J'
node=qualification-a
strategy=A
candidate_limit=12
shortlist_count=4
workspace_budget_gib=10
purpose=local deterministic A qualification
J
cat > "$TMP/b.conf" <<'J'
node=qualification-b
strategy=B
candidate_limit=24
shortlist_count=4
workspace_budget_gib=7
purpose=local deterministic B qualification
J
cat > "$TMP/c.conf" <<'J'
node=qualification-c
strategy=C
candidate_limit=60
shortlist_count=4
workspace_budget_gib=10
purpose=local deterministic C qualification
J
cat > "$TMP/d.conf" <<'J'
node=qualification-d
strategy=D
candidate_limit=24
shortlist_count=4
workspace_budget_gib=10
purpose=local deterministic D qualification
J
cat > "$TMP/i.conf" <<'J'
node=qualification-i
strategy=I
candidate_limit=24
shortlist_count=4
workspace_budget_gib=5
purpose=local high-cancellation residual I qualification
J
cat > "$TMP/e.conf" <<'J'
node=qualification-e
strategy=E
candidate_limit=30
shortlist_count=4
workspace_budget_gib=5
purpose=local deterministic checkpointed E qualification
cloud_provider=gcp
cloud_zone=us-central1-f
machine_type=e2-micro
provisioning_model=standard
J
export REXX_PATH="$ROOT/lib:$ROOT/foreign:$OOREXX_PREFIX/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/foreign:$OOREXX_PREFIX/lib:$OOREXX_PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export AUDIO_SEARCH_FSYNC_HELPER="$ROOT/foreign/audio_checkpoint_fsync"
run_one(){
  local job=$1 out=$2 limit=$3 expected=$4
  rm -rf "$out"; mkdir -p "$out"
  SEARCH_LIMIT="$limit" "$REXX_BIN" "$ROOT/bin/AudioSearchExperiment.rex" "$job" "$TMP/source.wav" "$TMP/companion.wav" \
    "$ROOT/reference/QUALITY_CORPUS.tsv" \
    "$out" "$ROOT/foreign/audio-search-native.bridge.json"
  jq -e --arg s "$expected" '.strategy == $s and .python_execution == false and (.results|length)>0 and .results[0].config.gain_db != null' "$out/results.json" >/dev/null
}
run_e(){
  local state=$1 out=$2 limit=$3 key=${4:-qualification-e-key}
  rm -rf "$out"; mkdir -p "$out" "$state"
  AUDIO_SEARCH_STATE_DIR="$state" AUDIO_SEARCH_RESUME_KEY="$key" SEARCH_LIMIT="$limit" \
    "$REXX_BIN" "$ROOT/bin/AudioSearchExperiment.rex" "$TMP/e.conf" "$TMP/source.wav" "$TMP/companion.wav" \
    "$ROOT/reference/QUALITY_CORPUS.tsv" \
    "$out" "$ROOT/foreign/audio-search-native.bridge.json"
  jq -e '.strategy == "E" and .python_execution == false and .ml.resume_supported == true and .execution_context.provisioning_model == "standard"' "$out/results.json" >/dev/null
}
run_one "$TMP/a.conf" "$TMP/a1" 12 A
run_one "$TMP/b.conf" "$TMP/b1" 24 B
run_one "$TMP/c.conf" "$TMP/csmall" 20 C
run_one "$TMP/c.conf" "$TMP/c1" 60 C
run_one "$TMP/c.conf" "$TMP/c2" 60 C
run_one "$TMP/d.conf" "$TMP/d1" 24 D
run_one "$TMP/i.conf" "$TMP/i1" 24 I
jq -e '.workspace_budget_gib == 7 and .results[0].config.cancel_strength != null and (.search_contract.workspace | contains("WORKSPACE=max=7516192768")) and (.search_contract.retention | contains("uniqueBy=PCM_HASH"))' "$TMP/b1/results.json" >/dev/null
jq -e '.results[0].config.cancel_strength != null' "$TMP/d1/results.json" >/dev/null
jq -e '.strategy == "I" and (.results | all(.config.cancel_strength >= 0.60))' "$TMP/i1/results.json" >/dev/null
jq -e '.ml.population_size == 6 and .ml.evaluated_population_rounds == 3 and .ml.breeding_steps == 2 and .ml.final_population_evaluated == true and .ml.evaluation_slots == 18 and .ml.unused_slots == 2 and .ml.final_population_generation == 2 and .ml.generation_registry_count == 3' "$TMP/csmall/results.json" >/dev/null
jq -e '.engine | contains("ooRexx ML v0.1-dev5")' "$TMP/c1/results.json" >/dev/null
for d in a1 b1 csmall c1 c2 d1 i1; do
  [[ -s "$TMP/$d/pareto_candidates.tsv" ]] || { echo "FAIL: missing Pareto catalog $d" >&2; exit 3; }
  jq -e '.pareto.objective_set == "RECOVERED-AUDIO-PARETO-V2" and .pareto.non_dominated_count >= 1 and .pareto.scalar_score_status == "EXPERIMENTAL_UNTIL_PERCEPTUAL_CALIBRATION" and (.pareto.objectives | index("reference_distance")) != null and (.pareto.objectives | index("pre_limiter_over_fraction")) != null and (.pareto.objectives | index("post_limiter_clip_fraction")) != null' "$TMP/$d/results.json" >/dev/null
done
head -1 "$TMP/c1/pareto_candidates.tsv" | grep -q $'candidate_id\tlane_id\tscalar_rank\tscalar_score\tpareto_rank\tcrowding_distance\treference_distance\tpre_limiter_over_fraction\tpost_limiter_clip_fraction\tmaterial_ref\tchain' || { echo 'FAIL: Pareto catalog schema' >&2; exit 3; }
awk -F '\t' 'NR>1 && $5==1 {found=1} END{exit !found}' "$TMP/c1/pareto_candidates.tsv" || { echo 'FAIL: Pareto front has no rank-1 candidate' >&2; exit 3; }
jq -e '.ml.shared_parameter_domain == "C is an explicit superset of A/B/D shared gain/filter/denoise ranges" and .ml.space_relations.A_to_C == "LEFT_SUBSET" and .ml.space_relations.B_to_C == "LEFT_SUBSET" and .ml.space_relations.D_to_C == "LEFT_SUBSET" and .ml.search_driver == "MLGeneticAlgorithm~run" and .ml.objective.direction == "MINIMIZE"' "$TMP/c1/results.json" >/dev/null
cmp "$TMP/c1/results.json" "$TMP/c2/results.json"
for d in c1 c2; do (cd "$TMP/$d" && sha256sum rank_*.wav) | cut -d' ' -f1 > "$TMP/$d.hashes"; done
cmp "$TMP/c1.hashes" "$TMP/c2.hashes"

# dev5 review/calibration integration: every shortlist exports stable candidates,
# MLReview can compare blind listener judgements against the objective, and the
# controller-side review preparer can combine node catalogs without exposing scores
# in the pair manifest.
for d in a1 b1 c1 d1 i1; do [[ -s "$TMP/$d/review_candidates.tsv" ]] || { echo "FAIL: missing review catalog $d" >&2; exit 3; }; done
head -1 "$TMP/c1/review_candidates.tsv" | grep -q $'candidate_id\tlane_id\trank\tscore\tmaterial_ref' || { echo 'FAIL: review catalog schema' >&2; exit 3; }
mapfile -t review_ids < <(tail -n +2 "$TMP/c1/review_candidates.tsv" | head -3 | cut -f1)
[[ ${#review_ids[@]} -eq 3 ]] || { echo 'FAIL: calibration fixture candidates' >&2; exit 3; }
cat > "$TMP/judgements.tsv" <<J
judgement_id	reviewer_id	left_candidate_id	right_candidate_id	preference	confidence	rationale	evidence_ref
J1	listener-q	${review_ids[0]}	${review_ids[1]}	LEFT	0.9	first ranked clearer	listen-1
J2	listener-q	${review_ids[1]}	${review_ids[2]}	LEFT	0.8	second ranked clearer	listen-2
J3	listener-q	${review_ids[0]}	${review_ids[2]}	LEFT	0.9	first ranked clearer	listen-3
J
"$REXX_BIN" "$ROOT/bin/AudioObjectiveCalibration.rex" "$TMP/c1/review_candidates.tsv" "$TMP/judgements.tsv" "$TMP/calibration" .70 3
jq -e '.schema == "audio.objective.calibration/1" and .qualified == true and .comparable_judgements == 3 and .agreement_rate == 1' "$TMP/calibration/calibration.json" >/dev/null
mkdir -p "$TMP/collected/ed209a" "$TMP/collected/ed209c"
cp "$TMP/a1/review_candidates.tsv" "$TMP/collected/ed209a/"
cp "$TMP/c1/review_candidates.tsv" "$TMP/collected/ed209c/"
cp "$TMP/a1"/rank_*.wav "$TMP/collected/ed209a/"
cp "$TMP/c1"/rank_*.wav "$TMP/collected/ed209c/"
PAIR_COUNT=6 "$ROOT/prepare_review.sh" "$TMP/collected" "$TMP/review-work"
[[ $(($(wc -l < "$TMP/review-work/review_pairs.tsv")-1)) -gt 0 ]] || { echo 'FAIL: no review pairs prepared' >&2; exit 3; }
if grep -qi 'score' "$TMP/review-work/review_pairs.tsv"; then echo 'FAIL: blind pair manifest exposes scores' >&2; exit 3; fi

# E checkpoint/resume: qualify 12 slots, resume the same durable sequence to 20, and
# compare ranked signal output with a clean 20-slot replay.
run_e "$TMP/e-resume-state" "$TMP/e12" 12
run_e "$TMP/e-resume-state" "$TMP/e20-resume" 20
run_e "$TMP/e-clean-state" "$TMP/e20-clean" 20
jq -e '.ml.processed_before_resume == 12 and .ml.processed_slots == 20 and .ml.checkpoint_records_loaded > 0' "$TMP/e20-resume/results.json" >/dev/null
jq -e '.ml.processed_before_resume == 0 and .ml.processed_slots == 20' "$TMP/e20-clean/results.json" >/dev/null
jq -S '.results' "$TMP/e20-resume/results.json" > "$TMP/e20-resume.results"
jq -S '.results' "$TMP/e20-clean/results.json" > "$TMP/e20-clean.results"
cmp "$TMP/e20-resume.results" "$TMP/e20-clean.results"
for d in e20-resume e20-clean; do (cd "$TMP/$d" && sha256sum rank_*.wav) | cut -d' ' -f1 > "$TMP/$d.hashes"; done
cmp "$TMP/e20-resume.hashes" "$TMP/e20-clean.hashes"
grep -q '^processed_slots=20$' "$TMP/e-resume-state/exploration.state"
[[ -s "$TMP/e-resume-state/exploration_records.tsv" ]]
# A checkpoint is package/job/sample-bound and must fail closed under a new key.
if AUDIO_SEARCH_STATE_DIR="$TMP/e-resume-state" AUDIO_SEARCH_RESUME_KEY='wrong-key' SEARCH_LIMIT=21 \
  "$REXX_BIN" "$ROOT/bin/AudioSearchExperiment.rex" "$TMP/e.conf" "$TMP/source.wav" "$TMP/companion.wav" \
  "$ROOT/reference/QUALITY_CORPUS.tsv" \
  "$TMP/e-bad-key" "$ROOT/foreign/audio-search-native.bridge.json" >/dev/null 2>&1; then
  echo 'FAIL: Strategy E accepted mismatched resume key' >&2; exit 3
fi

# Native multi-band rejection + second-stage voice-positive refinement.
# Use a two-tone source so qualification proves the rejected band is actually
# suppressed while an unrelated band is preserved, not merely that the PCM hash changes.
BANDTMP="$TMP/band"
mkdir -p "$BANDTMP"
ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i 'sine=frequency=500:sample_rate=16000:duration=5' \
  -f lavfi -i 'sine=frequency=2000:sample_rate=16000:duration=5' \
  -filter_complex '[0:a][1:a]amix=inputs=2:normalize=0' -ac 1 -c:a pcm_s16le "$BANDTMP/two.wav"
printf '%s\n' NONE '450-550' '450-550;1900-2100' > "$BANDTMP/plans.txt"
AUDIO_BAND_PLAN_FILE="$BANDTMP/plans.txt" \
  "$REXX_BIN" "$ROOT/bin/AudioBandRefinement.rex" "$BANDTMP/two.wav" \
  "$ROOT/reference/QUALITY_CORPUS.tsv" \
  "$BANDTMP/out" "$ROOT/foreign/audio-search-native.bridge.json" 'qualification-parent' 3
jq -e '.schema == "audio.band.refinement/1" and .python_execution == false and .evaluated_plan_count == 3 and (.results|length) == 3' "$BANDTMP/out/band_results.json" >/dev/null
[[ -s "$BANDTMP/out/review_candidates.tsv" ]] || { echo 'FAIL: band refinement review catalog' >&2; exit 3; }
mean_at(){
  local f=$1 freq=$2
  ffmpeg -nostdin -hide_banner -i "$f" -af "bandpass=f=$freq:width_type=h:w=80,volumedetect" -f null - 2>&1 \
    | sed -n 's/.*mean_volume: \([-0-9.]*\) dB.*/\1/p' | tail -1
}
base_file=$(jq -r '.results[]|select(.reject_bands=="")|.output' "$BANDTMP/out/band_results.json")
one_file=$(jq -r '.results[]|select(.reject_bands=="450-550")|.output' "$BANDTMP/out/band_results.json")
two_file=$(jq -r '.results[]|select(.reject_bands=="450-550;1900-2100")|.output' "$BANDTMP/out/band_results.json")
base500=$(mean_at "$BANDTMP/out/$base_file" 500); one500=$(mean_at "$BANDTMP/out/$one_file" 500)
base2000=$(mean_at "$BANDTMP/out/$base_file" 2000); one2000=$(mean_at "$BANDTMP/out/$one_file" 2000); two2000=$(mean_at "$BANDTMP/out/$two_file" 2000)
awk -v b="$base500" -v r="$one500" 'BEGIN{exit !((r-b)<=-15)}' || { echo "FAIL: 450-550 rejection insufficient baseline=$base500 rejected=$one500" >&2; exit 3; }
awk -v b="$base2000" -v r="$one2000" 'BEGIN{d=r-b;if(d<0)d=-d;exit !(d<=1.5)}' || { echo "FAIL: unrelated 2kHz band changed too much baseline=$base2000 filtered=$one2000" >&2; exit 3; }
awk -v b="$base2000" -v r="$two2000" 'BEGIN{exit !((r-b)<=-15)}' || { echo "FAIL: second rejected band insufficient baseline=$base2000 rejected=$two2000" >&2; exit 3; }
printf '%s\n' '100-200;300-400;500-600;700-800;900-1000;1100-1200;1300-1400' > "$BANDTMP/too-many.txt"
if AUDIO_BAND_PLAN_FILE="$BANDTMP/too-many.txt" \
  "$REXX_BIN" "$ROOT/bin/AudioBandRefinement.rex" "$BANDTMP/two.wav" \
  "$ROOT/reference/QUALITY_CORPUS.tsv" \
  "$BANDTMP/bad" "$ROOT/foreign/audio-search-native.bridge.json" bad 1 >/dev/null 2>&1; then
  echo 'FAIL: more than six reject bands accepted' >&2; exit 3
fi

# dev7 H additive voice mix: preserve ordinary H ranking, derive one extra
# human-review material by summing rank 1 with the quietest distinct member of
# the top-24 H pool.  The residual is chosen by actual output RMS, not a hard-
# coded rank; the final mix receives the same sample-local limiter and no peak
# normalization.
HMIX="$TMP/hmix"
mkdir -p "$HMIX"
cat > "$HMIX/parent.conf" <<'J'
parent_candidate_id=qualification-hmix-parent
parent_chain=gain=30dB -> cancel=0.75@0ms -> hp=40Hz -> lp=3000Hz -> soft_limiter=.88/.98
gain_db=30
highpass_hz=40
lowpass_hz=3000
denoise_floor_db=NONE
echo_delay_ms=0
echo_gain=0
cancel_strength=0.75
cancel_tweak_ms=0
compress=0
compress_ratio=2
compress_threshold_db=-18
reject_bands=
J
cat > "$HMIX/window.conf" <<'J'
window_id=ROLL_p0
relative_offset_sec=0
source_start_sec=0
source_duration_sec=2
companion_start_sec=0
companion_duration_sec=3
J
AUDIO_H_VOICE_MIX_ENABLED=1 AUDIO_H_VOICE_MIX_POOL_DEPTH=24 AUDIO_H_VOICE_MIX_MIN_ATTENUATION_DB=0 \
  "$REXX_BIN" "$ROOT/bin/AudioTemporalBandRefinement.rex" "$TMP/source.wav" "$TMP/companion.wav" \
  "$ROOT/reference/QUALITY_CORPUS.tsv" \
  "$HMIX/out" "$ROOT/foreign/audio-search-native.bridge.json" "$HMIX/parent.conf" "$HMIX/window.conf" 6
jq -e '.schema == "audio.temporal.band.refinement/1" and .additive_voice_mix.schema == "audio.h.additive.voice-mix/1" and .additive_voice_mix.selection == "rank-1-plus-quietest-top24-residual" and .additive_voice_mix.pool_depth == 24 and .additive_voice_mix.primary_rank == 1 and (.additive_voice_mix.residual_rank >= 2 and .additive_voice_mix.residual_rank <= 24) and .additive_voice_mix.parent_cancel_strength == 0.75 and .additive_voice_mix.primary_gain == 1 and .additive_voice_mix.residual_gain == 1 and .additive_voice_mix.final_limiter == "sample-local-.88-.98-no-normalization"' "$HMIX/out/temporal_band_results.json" >/dev/null
[[ -s "$HMIX/out/h_voice_mix.wav" && -s "$HMIX/out/h_voice_residual.wav" && -s "$HMIX/out/voice_mix.tsv" ]] || { echo 'FAIL: H additive voice mix material/evidence missing' >&2; exit 3; }
[[ $(wc -l < "$HMIX/out/voice_mix.tsv") -eq 2 ]] || { echo 'FAIL: H additive voice mix evidence row' >&2; exit 3; }
for f in h_voice_mix.wav h_voice_residual.wav; do
  ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,bits_per_sample -of default=nw=1 "$HMIX/out/$f" | grep -q '^sample_rate=16000$' || { echo "FAIL: H mix sample rate $f" >&2; exit 3; }
done
mix_hash=$(sha256sum "$HMIX/out/h_voice_mix.wav" | awk '{print $1}')
rank1_hash=$(sha256sum "$HMIX/out/h_rank_01.wav" | awk '{print $1}')
res_hash=$(sha256sum "$HMIX/out/h_voice_residual.wav" | awk '{print $1}')
[[ "$mix_hash" != "$rank1_hash" && "$mix_hash" != "$res_hash" ]] || { echo 'FAIL: additive voice mix is not distinct derived material' >&2; exit 3; }
grep -q '^voice_mix_enabled=1$' "$ROOT/jobs/ed209h.conf" || { echo 'FAIL: H mix default disabled' >&2; exit 3; }
grep -q '^voice_mix_pool_depth=24$' "$ROOT/jobs/ed209h.conf" || { echo 'FAIL: H mix pool-depth contract' >&2; exit 3; }
grep -q 'H_VOICE_MIX.tsv' "$ROOT/h_refinement_worker.sh" || { echo 'FAIL: H aggregate mix evidence missing' >&2; exit 3; }

find "$ROOT" -type f -name '*.py' -print -quit | grep -q . && { echo 'FAIL: Python file found in Rexx-native pack' >&2; exit 3; }
grep -RIlE 'ForeignPython|python3[[:space:]]' "$ROOT/bin" "$ROOT/lib" "$ROOT/native" "$ROOT/foreign" 2>/dev/null | grep -q . && { echo 'FAIL: Python execution reference found' >&2; exit 3; } || true
grep -q "NODES='ed209a,ed209b,ed209c,ed209d,ed209e,ed209i'" "$ROOT/deploy_all.sh" || { echo 'FAIL: six-node default deployment set' >&2; exit 3; }
grep -q 'deploy_one "\$n".*&' "$ROOT/deploy_all.sh" || { echo 'FAIL: node deployment is not parallel/failure-isolated' >&2; exit 3; }
grep -q '^remote_base=audio-rexx-search-v0.12-dev12$' "$ROOT/deploy_all.sh" || { echo 'FAIL: dev7 remote root contract' >&2; exit 3; }
grep -q '^workspace_budget_gib=7$' "$ROOT/jobs/ed209b.conf" || { echo 'FAIL: ed209b 7 GiB budget contract' >&2; exit 3; }
grep -q '^strategy=E$' "$ROOT/jobs/ed209e.conf" || { echo 'FAIL: ed209e Strategy E contract' >&2; exit 3; }
grep -q '^provisioning_model=standard$' "$ROOT/jobs/ed209e.conf" || { echo 'FAIL: ed209e standard GCP contract' >&2; exit 3; }
grep -q '^memory_total_min_mib=850$' "$ROOT/jobs/ed209e.conf" || { echo 'FAIL: ed209e 1 GiB-class memory floor' >&2; exit 3; }
grep -q '^strategy=I$' "$ROOT/jobs/ed209i.conf" || { echo 'FAIL: ed209i Strategy I contract' >&2; exit 3; }
grep -q '^swap_total_min_mib=1536$' "$ROOT/jobs/ed209i.conf" || { echo 'FAIL: ed209i swap floor contract' >&2; exit 3; }
grep -q 'ED209I_HOST:-20.114.63.150' "$ROOT/deploy_all.sh" || { echo 'FAIL: ed209i host fallback contract' >&2; exit 3; }
grep -q 'ED209E_HOST:-34.28.240.217' "$ROOT/deploy_all.sh" || { echo 'FAIL: ed209e current-IP fallback contract' >&2; exit 3; }
grep -q 'GCP_KEY' "$ROOT/deploy_all.sh" || { echo 'FAIL: ed209e optional GCP key override' >&2; exit 3; }
grep -q 'pre-boot\|boot' "$ROOT/README.md" 2>/dev/null || true
grep -q 'MLObjectiveFitnessAdapter' "$ROOT/bin/AudioSearchExperiment.rex" || { echo 'FAIL: dev5 objective adapter not used by audio search' >&2; exit 3; }
grep -q '::class AudioGAScoreEvaluator' "$ROOT/bin/AudioSearchExperiment.rex" || { echo 'FAIL: natural-score evaluator missing' >&2; exit 3; }
[[ -f "$ROOT/lib/MLReview.cls" ]] || { echo 'FAIL: MLReview dev5 class missing' >&2; exit 3; }
grep -q 'MLObjectiveCalibrationSession' "$ROOT/bin/AudioObjectiveCalibration.rex" || { echo 'FAIL: calibration integration missing' >&2; exit 3; }

echo 'PASS ALL REXX-NATIVE AUDIO SEARCH v0.12-dev12 LOCAL TESTS'
