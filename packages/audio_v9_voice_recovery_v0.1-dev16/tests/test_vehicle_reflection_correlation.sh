#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/vehicle_reflection"
rm -rf "$T"; mkdir -p "$T"
printf 'observation_id\tstart_ms\tend_ms\tsource_id\tfeed\tpath_kind\tdelay_samples\tapparent_gain_db\taudio_score\tloud_probe\tprovenance\n' > "$T/audio.tsv"
printf 'A1\t1000\t1400\tSRC_WHISPER\tFD\tTRANSIENT_REFLECTION\t96\t8.1\t0.91\t0\tAUDIO\n' >> "$T/audio.tsv"
printf 'A2\t2000\t2400\tSRC_WHISPER\tFD\tTRANSIENT_REFLECTION\t104\t7.9\t0.20\t0\tAUDIO\n' >> "$T/audio.tsv"
printf 'reflector_id\tstart_ms\tend_ms\tgeometry_score\tprovenance\n' > "$T/video.tsv"
printf 'CAR_1\t900\t1500\t0.94\tVIDEO_TRACK\n' >> "$T/video.tsv"
printf 'CAR_2\t1900\t2500\t0.97\tVIDEO_TRACK\n' >> "$T/video.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/correlate_vehicle_reflections.rex" "$T/audio.tsv" "$T/video.tsv" "$T/out.tsv" >/dev/null
[ "$(awk 'END{print NR-1}' "$T/out.tsv")" -eq 2 ] || { echo 'FAIL vehicle reflection output rows' >&2; exit 1; }
awk -F '\t' 'NR==2 { gsub(/\"/,"",$11); gsub(/\"/,"",$14); if ($10 < .93 || $11 != "CAR_1" || $14 != "AUDIO_PLUS_VIDEO") exit 1 } NR==3 { gsub(/\"/,"",$11); gsub(/\"/,"",$14); if ($10 < .96 || $11 != "CAR_2" || $14 != "VISUAL_ONLY_CANDIDATE") exit 1 }' "$T/out.tsv" || { echo 'FAIL vehicle reflection authority boundary' >&2; exit 1; }
echo 'PASS vehicle reflection correlation authority rows=2'
