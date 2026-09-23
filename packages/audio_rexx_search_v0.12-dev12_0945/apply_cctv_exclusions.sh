#!/usr/bin/env bash
set -euo pipefail
IN=${1:?usage: apply_cctv_exclusions.sh INPUT.wav MASK.tsv OUTPUT.wav [SHIFT_SEC]}
MASK=${2:?}
OUT=${3:?}
SHIFT=${4:-0}
command -v ffmpeg >/dev/null 2>&1 || { echo 'ffmpeg is required' >&2; exit 2; }
filters=()
while IFS=$'\t' read -r s e reason _; do
  [[ -n "$s" && "$s" != start_sec && "$s" != \#* ]] || continue
  [[ "$reason" == cctv_alarm ]] || continue
  ss=$(awk -v x="$s" -v d="$SHIFT" 'BEGIN{v=x+d;if(v<0)v=0;printf "%.6f",v}')
  ee=$(awk -v x="$e" -v d="$SHIFT" 'BEGIN{v=x+d;if(v<0)v=0;printf "%.6f",v}')
  filters+=("volume=0:enable='between(t,$ss,$ee)'")
done < "$MASK"
if ((${#filters[@]}==0)); then
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$IN" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT"
else
  chain=$(IFS=,; echo "${filters[*]}")
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$IN" -af "$chain" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT"
fi
