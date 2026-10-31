#!/bin/sh
# SPASH original-source -> Audio V9 Candidate21 measured multipath ->
# conservative virtual-microphone reconstruction (STAGE 1 + STAGE 2 ONLY).
# Required locally patched owner source: Audio V9 Candidate21 with the
# AudioV9TsvWriter + quoted TSV native reader interoperability fix.
# No Python audio DSP, no guessed FC/FD clock, no POI1 processing.
set -eu
if [ "$#" -ne 7 ]; then
  echo 'usage: run_spash_candidate21_native.sh ORIGINAL.ogg FD|FC OFFSET_SECONDS CHANNEL_INDEX CANDIDATE21_DIR REXX_BIN OUTPUT_DIR' >&2
  exit 2
fi
source=$1; feed=$2; offset=$3; channel=$4; owner=$5; rexxbin=$6; output=$7
case "$feed" in FC|FD) ;; *) echo 'FAIL feed' >&2; exit 2;; esac
case "$offset" in *[!0-9.]*|'') echo 'FAIL offset' >&2; exit 2;; esac
case "$channel" in 0|1|2) ;; *) echo 'FAIL channel' >&2; exit 2;; esac
[ -f "$source" ] || { echo 'FAIL original missing' >&2; exit 2; }
[ -x "$rexxbin" ] || { echo 'FAIL ooRexx missing' >&2; exit 2; }
[ -x "$owner/build/av9_multipath_spectral_track" ] || { echo 'FAIL AudioV9 native spectral provider absent' >&2; exit 2; }
[ -x "$owner/build/av9_virtual_mic_dynamic" ] || { echo 'FAIL AudioV9 native virtual mic provider absent' >&2; exit 2; }
[ -e "$output" ] && { echo 'FAIL output exists; immutable derivative policy' >&2; exit 2; }
mkdir -m 0700 "$output"
export REXX_PATH="$owner/src${REXX_PATH:+:$REXX_PATH}"
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Decode context-bearing 15-second source window at native owner input format.
# Ogg source offsets are requests, not validated cross-camera clocks.
ffmpeg -nostdin -v error -ss "$offset" -i "$source" -t 15 -map 0:a:0 \
  -af "pan=mono|c0=c$channel" -ar 8000 -f f32le "$output/context_15s.f32"
[ "$(wc -c < "$output/context_15s.f32")" -ge 400000 ] || { echo 'FAIL incomplete 15-second context' >&2; exit 3; }
"$owner/build/av9_multipath_spectral_track" "$output/context_15s.f32" \
  20000 100000 8000 "$feed" 24 20 > "$output/measured_spectral_paths.tsv"
"$rexxbin" "$root/spash_candidate21_plan.rex" "$output/measured_spectral_paths.tsv" "$output/virtual_mic_plan.tsv"
"$owner/build/av9_virtual_mic_dynamic" "$output/context_15s.f32" \
  "$output/virtual_mic_plan.tsv" "$output/reconstructed_nonamp.f32" \
  20000 100000 8000 "$feed" 40 0
"$owner/build/av9_virtual_mic_dynamic" "$output/context_15s.f32" \
  "$output/virtual_mic_plan.tsv" "$output/reconstructed_plus32_requested.f32" \
  20000 100000 8000 "$feed" 40 32
for suffix in reconstructed_nonamp reconstructed_plus32_requested; do
  [ "$(wc -c < "$output/$suffix.f32")" -eq 320000 ] || { echo 'FAIL reconstruction sample count' >&2; exit 3; }
  ffmpeg -nostdin -v error -f f32le -ar 8000 -ac 1 -i "$output/$suffix.f32" \
    -c:a pcm_s16le "$output/$suffix.wav"
done
sha256sum "$source" > "$output/original_source_sha256_private.txt"
( cd "$output" && sha256sum context_15s.f32 measured_spectral_paths.tsv \
  virtual_mic_plan.tsv reconstructed_nonamp.f32 reconstructed_plus32_requested.f32 \
  reconstructed_nonamp.wav reconstructed_plus32_requested.wav > SHA256SUMS )
{
  echo 'schema=spash.native-virtual-audio/0.4'
  echo "source_original=$source"
  echo "feed=$feed"
  echo "channel_index=$channel"
  echo "source_requested_offset_seconds=$offset"
  echo 'context_duration_seconds=15'
  echo 'local_reconstructed_start_second=2.5'
  echo 'local_reconstructed_end_second=12.5'
  echo 'reconstructed_sample_count=80000'
  echo 'audio_v9_method=AUDIO.RECON.MULTIPATH_VIRTUAL_MIC'
  echo 'audio_v9_source_package=Candidate21_with_local_TSV_interoperability_fix'
  echo 'evidence_gain_db=0'
  echo 'derived_listening_gain_db_requested=32'
  echo 'listening_gain_may_be_globally_peak_limited=true'
  echo 'poi1_processed=false'
  echo 'physical_view_count=1'
  echo 'virtual_mic_path=MEASURED_MULTIPATH_DERIVED_NOT_NEW_PHYSICAL_MIC'
  echo 'cross_camera_clock_alignment=UNVERIFIED'
  echo 'spash_final_query_result=NOT_RUN'
  echo '3d_unique_source_location=NOT_ESTABLISHED'
  echo 'output_authority=STAGE2_RECONSTRUCTED_CANDIDATE_ONLY'
} > "$output/STAGE2_RECEIPT.txt"
echo 'PASS SPASH native Candidate21 measured-path reconstruction, stage 2 only'
