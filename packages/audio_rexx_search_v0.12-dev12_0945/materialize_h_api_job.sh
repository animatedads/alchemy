#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
JOB=${1:?job envelope required}
OUT=${2:?output input directory required}
AUDIO_ROOT=${3:?audio root required}
command -v ffmpeg >/dev/null 2>&1 || { echo 'FAIL: ffmpeg required on ed209h for rolling-window materialization' >&2; exit 3; }
[[ -s "$JOB" ]] || { echo "FAIL: missing H API job envelope $JOB" >&2; exit 4; }
kv(){ awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$JOB"; }
schema=$(kv schema); job_id=$(kv job_id); [[ "$schema" == audio.h.refinement.control/2 ]] || { echo "FAIL: H API schema $schema" >&2; exit 4; }
[[ "$job_id" =~ ^[A-Za-z0-9._-]{1,80}$ ]] || { echo 'FAIL: unsafe H job id' >&2; exit 4; }
source_rec=$(kv source_recording); companion_rec=$(kv companion_recording)
for f in "$source_rec" "$companion_rec"; do [[ -n "$f" && "$f" != */* && "$f" != *..* ]] || { echo "FAIL: unsafe source recording name $f" >&2; exit 4; }; done
SOURCE="$AUDIO_ROOT/$source_rec"; COMPANION="$AUDIO_ROOT/$companion_rec"
[[ -s "$SOURCE" && -s "$COMPANION" ]] || { echo "FAIL: H source recordings not present under $AUDIO_ROOT" >&2; exit 4; }
base_source=$(kv source_start_sec); base_companion=$(kv companion_start_sec); companion_duration=$(kv companion_duration_sec)
radius=$(kv temporal_radius_sec); window=$(kv window_duration_sec); step=$(kv window_step_sec); overlap=$(kv window_overlap_sec); parents=$(kv parent_count)
for v in "$base_source" "$base_companion" "$companion_duration" "$radius" "$window" "$step" "$overlap" "$parents"; do [[ "$v" =~ ^[0-9]+$ ]] || { echo 'FAIL: H job timing/count fields must be unsigned integers' >&2; exit 4; }; done
(( parents>=1 && parents<=20 && window>=30 && step>=10 && step<=window && overlap==window-step )) || { echo 'FAIL: H job window/parent policy' >&2; exit 4; }
rm -rf "$OUT"; mkdir -p "$OUT/candidates" "$OUT/windows"
printf 'parent_node\tparent_rank\tparent_candidate_id\tconfig_file\n' > "$OUT/inputs.tsv"
for ((n=1;n<=parents;n++)); do
  p="parent.$n"
  getp(){ kv "$p.$1"; }
  node=$(getp node); rank=$(getp rank); cid=$(getp candidate_id)
  [[ "$node" =~ ^[A-Za-z0-9._-]+$ && "$rank" =~ ^[0-9]+$ && -n "$cid" ]] || { echo "FAIL: malformed H parent $n" >&2; exit 4; }
  safe=$(printf 'parent_%02d_%s_rank_%02d' "$n" "$node" "$rank" | tr -cs 'A-Za-z0-9._-' '_')
  conf="$OUT/candidates/$safe.conf"
  {
    echo "parent_node=$node"
    echo "parent_rank=$rank"
    echo "parent_candidate_id=$cid"
    echo "parent_score=$(getp score)"
    echo "parent_chain=$(getp chain)"
    echo "gain_db=$(getp gain_db)"
    echo "highpass_hz=$(getp highpass_hz)"
    echo "lowpass_hz=$(getp lowpass_hz)"
    echo "denoise_floor_db=$(getp denoise_floor_db)"
    echo "echo_delay_ms=$(getp echo_delay_ms)"
    echo "echo_gain=$(getp echo_gain)"
    echo "cancel_strength=$(getp cancel_strength)"
    echo "cancel_tweak_ms=$(getp cancel_tweak_ms)"
    echo "compress=$(getp compress)"
    echo "compress_ratio=$(getp compress_ratio)"
    echo "compress_threshold_db=$(getp compress_threshold_db)"
    echo "reject_bands=$(getp reject_bands)"
  } > "$conf"
  printf '%s\t%s\t%s\t%s\n' "$node" "$rank" "$cid" "candidates/$safe.conf" >> "$OUT/inputs.tsv"
done
printf 'window_id\trelative_offset_sec\tsource_start_sec\tsource_duration_sec\tcompanion_start_sec\tcompanion_duration_sec\tsource_file\tcompanion_file\n' > "$OUT/windows/windows.tsv"
offsets=()
for ((o=-radius; o<=radius; o+=step)); do offsets+=("$o"); done
(( ${offsets[${#offsets[@]}-1]} == radius )) || offsets+=("$radius")
for off in "${offsets[@]}"; do
  ss=$((base_source+off)); cs=$((base_companion+off))
  (( ss>=0 && cs>=0 )) || { echo "FAIL: rolling window offset=$off precedes source start" >&2; exit 4; }
  if (( off<0 )); then tag="m$((-off))"; elif (( off>0 )); then tag="p$off"; else tag=p0; fi
  sf="source_${tag}.wav"; cf="companion_${tag}.wav"; wid="ROLL_${tag}"
  ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$ss" -t "$window" -i "$SOURCE" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT/windows/$sf"
  ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$cs" -t "$companion_duration" -i "$COMPANION" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT/windows/$cf"
  [[ -s "$OUT/windows/$sf" && -s "$OUT/windows/$cf" ]] || { echo "FAIL: empty H rolling material offset=$off" >&2; exit 5; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$wid" "$off" "$ss" "$window" "$cs" "$companion_duration" "$sf" "$cf" >> "$OUT/windows/windows.tsv"
done
(cd "$OUT" && find . -type f ! -name INPUTS.sha256 -print0 | sort -z | xargs -0 sha256sum > INPUTS.sha256)
echo "MATERIALIZED H API JOB id=$job_id parents=$parents windows=$(($(wc -l < "$OUT/windows/windows.tsv")-1)) input=$OUT"
