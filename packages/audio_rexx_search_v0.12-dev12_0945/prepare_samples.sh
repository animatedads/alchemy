#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TP6_NAME=20231010_093912_tp00006_original.ogg
TP23_NAME=20231010_090927_tp00023_original.ogg
TP24_NAME=20231010_094521_tp00024_original.ogg
find_source() {
  local env_value=$1 name=$2 p
  if [[ -n "$env_value" ]]; then [[ -f "$env_value" ]] || return 1; printf '%s\n' "$env_value"; return 0; fi
  for p in "$ROOT/../fcpaphos/$name" "$PWD/fcpaphos/$name" "$HOME/alchemy-autobuild/fcpaphos/$name" "$HOME/fcpaphos/$name" "/srv/space/fcpaphos/$name"; do
    [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  if [[ -d "$HOME/alchemy-autobuild" ]]; then p=$(find "$HOME/alchemy-autobuild" -type f -name "$name" -print -quit 2>/dev/null || true); [[ -n "$p" ]] && { printf '%s\n' "$p"; return 0; }; fi
  return 1
}
command -v ffmpeg >/dev/null 2>&1 || { echo 'ffmpeg is required on the controller.' >&2; exit 2; }
command -v ffprobe >/dev/null 2>&1 || { echo 'ffprobe is required on the controller.' >&2; exit 2; }
TP6=$(find_source "${TP00006_SOURCE:-}" "$TP6_NAME") || { echo "Cannot locate $TP6_NAME; set TP00006_SOURCE." >&2; exit 2; }
TP23=$(find_source "${TP00023_SOURCE:-}" "$TP23_NAME") || { echo "Cannot locate $TP23_NAME; set TP00023_SOURCE." >&2; exit 2; }
TP24=$(find_source "${TP00024_SOURCE:-}" "$TP24_NAME") || { echo "Cannot locate $TP24_NAME; set TP00024_SOURCE." >&2; exit 2; }
mkdir -p "$ROOT/sample" "$ROOT/alignment_reference" "$ROOT/campaign_audio" "$ROOT/run" "$ROOT/exclusions"
SOURCE_MASTER="$ROOT/campaign_audio/campaign0945_source_094030_094930.wav"
COMP_MASTER="$ROOT/campaign_audio/campaign0945_companion_094015_094945.wav"
SOURCE_RAW="$ROOT/run/campaign0945_source_094030_094930.unmasked.wav"
COMP_RAW="$ROOT/run/campaign0945_companion_094015_094945.unmasked.wav"
ALARM_MASK="$ROOT/exclusions/campaign0945_cctv_alarm_source_master.tsv"
COMP_A="$ROOT/run/campaign0945_companion_tp23_part.wav"
COMP_B="$ROOT/run/campaign0945_companion_tp24_part.wav"
# Primary tp00006 starts 09:39:12. 09:45:00 -> offset 348.
# H source master 09:40:30..09:49:30 -> offset 78..618.
ffmpeg -nostdin -hide_banner -loglevel error -y -ss 78 -i "$TP6" -t 540 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$SOURCE_RAW.part.wav"
# Make the primary master sample-exact as well: 540 s * 16 kHz = 8,640,000 samples.
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$SOURCE_RAW.part.wav" \
  -af 'aresample=16000,asetpts=N/SR/TB,apad,atrim=end_sample=8640000' \
  -vn -ac 1 -ar 16000 -c:a pcm_s16le "$SOURCE_RAW"
rm -f "$SOURCE_RAW.part.wav"
# Companion is the continuous tp00023 -> tp00024 sequence with seam at 09:45:21.
# Required H companion master is 09:40:15..09:49:45 (±15 s around source master).
# tp00023 starts 09:09:27: 09:40:15 -> offset 1848, duration to seam = 306 s.
# tp00024 starts at seam and supplies the remaining 264 s.
ffmpeg -nostdin -hide_banner -loglevel error -y -ss 1848 -i "$TP23" -t 306 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$COMP_A"
ffmpeg -nostdin -hide_banner -loglevel error -y -ss 0 -i "$TP24" -t 264 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$COMP_B"
# Decode both sides before concatenation, then make sample count authoritative.
# Ogg/Vorbis packet/granule boundaries can make nominal -t excerpts slightly short.
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$COMP_A" -i "$COMP_B" \
  -filter_complex '[0:a][1:a]concat=n=2:v=0:a=1,aresample=16000,asetpts=N/SR/TB,apad,atrim=end_sample=9120000[a]' \
  -map '[a]' -vn -ac 1 -ar 16000 -c:a pcm_s16le "$COMP_RAW"
# Detect the exceptionally loud internal CCTV alarm from the ORIGINAL/unamplified
# primary master.  The thing we are recovering is the material that is *not*
# visible on the waveform; the obvious full-scale alarm is outside the search
# domain.  Preserve wall-clock/sample geometry by zeroing the excluded interval
# rather than deleting time.  Companion master begins 15 s earlier, hence +15.
"$ROOT/detect_cctv_alarm.sh" "$SOURCE_RAW" "$ALARM_MASK"
"$ROOT/apply_cctv_exclusions.sh" "$SOURCE_RAW" "$ALARM_MASK" "$SOURCE_MASTER" 0
"$ROOT/apply_cctv_exclusions.sh" "$COMP_RAW" "$ALARM_MASK" "$COMP_MASTER" 15
TARGET="$ROOT/sample/campaign0945_source_094330_094630.wav"
COMP="$ROOT/alignment_reference/campaign0945_companion_094315_094645.wav"
ffmpeg -nostdin -hide_banner -loglevel error -y -ss 180 -i "$SOURCE_MASTER" -t 180 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$TARGET"
ffmpeg -nostdin -hide_banner -loglevel error -y -ss 180 -i "$COMP_MASTER" -t 210 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$COMP"
# Publish parent-local intervals for human review/provenance.  Source parent is
# +180 s into the source master; companion parent is +180 s into a master that
# starts 15 s earlier.
awk -F '\t' 'BEGIN{OFS="\t"} /^#/ {next} $1=="start_sec" {print;next} {s=$1-180;e=$2-180;if(e<=0||s>=180)next;if(s<0)s=0;if(e>180)e=180;$1=s;$2=e;print}' "$ALARM_MASK" > "$ROOT/exclusions/campaign0945_parent_source.tsv"
awk -F '\t' 'BEGIN{OFS="\t"} /^#/ {next} $1=="start_sec" {print;next} {s=$1+15-180;e=$2+15-180;if(e<=0||s>=210)next;if(s<0)s=0;if(e>210)e=210;$1=s;$2=e;print}' "$ALARM_MASK" > "$ROOT/exclusions/campaign0945_parent_companion.tsv"
check_audio() {
  local f=$1 expected=$2 label=$3 duration probe duration_ts want_samples
  probe=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,channels -of default=nw=1:nk=1 "$f" | tr '\n' ' ')
  duration=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f")
  duration_ts=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of default=nw=1:nk=1 "$f")
  want_samples=$(awk -v sec="$expected" 'BEGIN{printf "%.0f",sec*16000}')
  [[ "$duration_ts" == "$want_samples" ]] || { echo "FAIL $label samples=$duration_ts expected=$want_samples duration=$duration" >&2; exit 5; }
  echo "PREPARED $label $(basename "$f"): $probe duration=$duration samples=$duration_ts"
}
check_audio "$SOURCE_MASTER" 540 source-master
check_audio "$COMP_MASTER" 570 companion-master
check_audio "$TARGET" 180 parent-source
check_audio "$COMP" 210 parent-companion
check_audio "$ROOT/reference/prepared/quality_target_01_whatsapp_16k_mono_pcm16.wav" 46.5 quality-target-1
check_audio "$ROOT/reference/prepared/quality_target_02_upspeak_16k_mono_pcm16.wav" 56.81925 quality-target-2
check_audio "$ROOT/reference/prepared/quality_target_03_quiet_voice_16k_mono_pcm16.wav" 48 quality-target-3
check_audio "$ROOT/reference/prepared/quality_target_04_high_register_16k_mono_pcm16.wav" 48 quality-target-4
(cd "$ROOT" && sha256sum \
  campaign_audio/campaign0945_source_094030_094930.wav \
  campaign_audio/campaign0945_companion_094015_094945.wav \
  sample/campaign0945_source_094330_094630.wav \
  alignment_reference/campaign0945_companion_094315_094645.wav \
  reference/prepared/*.wav \
  exclusions/campaign0945_cctv_alarm_source_master.tsv \
  exclusions/campaign0945_parent_source.tsv \
  exclusions/campaign0945_parent_companion.tsv > SAMPLES.sha256)
intervals=$(awk -F '\t' '!/^#/ && $1!="start_sec" {n++} END{print n+0}' "$ALARM_MASK")
"$ROOT/verify_prepared_samples.sh"
echo "PASS prepared 09:45 campaign fixture with AUDIO-QUALITY-TARGETS-V2 CCTV-ALARM-EXCLUSION-V1 intervals=$intervals"
