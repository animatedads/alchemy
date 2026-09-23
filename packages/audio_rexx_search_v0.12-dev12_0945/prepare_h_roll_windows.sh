#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${1:-$ROOT/run/controller/h-roll-windows}
BASE_JOB=${H_BASE_JOB:-$ROOT/jobs/ed209a.conf}
WINDOW_SEC=${H_ROLL_WINDOW_SEC:-180}
RADIUS_SEC=${H_ROLL_RADIUS_SEC:-180}
STEP_SEC=${H_ROLL_STEP_SEC:-90}
[[ $WINDOW_SEC =~ ^[0-9]+$ && $RADIUS_SEC =~ ^[0-9]+$ && $STEP_SEC =~ ^[0-9]+$ ]] || { echo 'FAIL: H rolling timing values must be integers' >&2; exit 2; }
(( WINDOW_SEC > 0 && RADIUS_SEC >= 0 && STEP_SEC > 0 && STEP_SEC <= WINDOW_SEC )) || { echo 'FAIL: require WINDOW>0, RADIUS>=0, 0<STEP<=WINDOW' >&2; exit 2; }
command -v ffmpeg >/dev/null 2>&1 || { echo 'FAIL: ffmpeg required on controller to prepare H rolling windows' >&2; exit 3; }
jobv(){ awk -F= -v k="$1" '$1==k{sub(/^[^=]*=/,""); print; exit}' "$BASE_JOB"; }
source_rec=$(jobv source_recording); companion_rec=$(jobv companion_recording)
base_source=$(jobv source_start_sec); base_companion=$(jobv companion_start_sec); companion_duration=$(jobv companion_duration_sec)
[[ $base_source =~ ^[0-9]+$ && $base_companion =~ ^[0-9]+$ && $companion_duration =~ ^[0-9]+$ ]] || { echo 'FAIL: base job lacks integer source/companion timing' >&2; exit 4; }
find_master(){
  local explicit=$1 name=$2 p
  if [[ -n "$explicit" && -f "$explicit" ]]; then printf '%s\n' "$explicit"; return 0; fi
  for p in "$ROOT/campaign_audio/$name" "$PWD/campaign_audio/$name" "$HOME/alchemy-autobuild/fcpaphos/$name" "$HOME/fcpaphos/$name"; do
    [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}
SOURCE=$(find_master "${H_SOURCE_MASTER:-}" "$source_rec") || { echo "FAIL: cannot locate campaign source master $source_rec; run prepare_samples.sh or set H_SOURCE_MASTER" >&2; exit 4; }
COMPANION=$(find_master "${H_COMPANION_MASTER:-}" "$companion_rec") || { echo "FAIL: cannot locate campaign companion master $companion_rec; run prepare_samples.sh or set H_COMPANION_MASTER" >&2; exit 4; }
rm -rf "$OUT"; mkdir -p "$OUT"
printf 'window_id\trelative_offset_sec\tsource_start_sec\tsource_duration_sec\tcompanion_start_sec\tcompanion_duration_sec\tsource_file\tcompanion_file\n' > "$OUT/windows.tsv"
offsets=()
for ((o=-RADIUS_SEC; o<=RADIUS_SEC; o+=STEP_SEC)); do offsets+=("$o"); done
last=${offsets[${#offsets[@]}-1]}
(( last == RADIUS_SEC )) || offsets+=("$RADIUS_SEC")
for off in "${offsets[@]}"; do
  ss=$((base_source + off)); cs=$((base_companion + off))
  (( ss >= 0 && cs >= 0 )) || { echo "FAIL H window offset=$off would precede campaign master start" >&2; exit 4; }
  if (( off < 0 )); then tag="m$((-off))"; elif (( off > 0 )); then tag="p$off"; else tag='p0'; fi
  sf="source_${tag}.wav"; cf="companion_${tag}.wav"; wid="ROLL_${tag}"
  ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$ss" -t "$WINDOW_SEC" -i "$SOURCE" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT/$sf"
  ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$cs" -t "$companion_duration" -i "$COMPANION" -vn -ac 1 -ar 16000 -c:a pcm_s16le "$OUT/$cf"
  [[ -s "$OUT/$sf" && -s "$OUT/$cf" ]] || { echo "FAIL: ffmpeg produced empty H rolling window offset=$off" >&2; exit 5; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$wid" "$off" "$ss" "$WINDOW_SEC" "$cs" "$companion_duration" "$sf" "$cf" >> "$OUT/windows.tsv"
done
count=$(( $(wc -l < "$OUT/windows.tsv") - 1 ))
(( count > 0 )) || { echo 'FAIL: no H rolling windows prepared' >&2; exit 5; }
(cd "$OUT" && find . -maxdepth 1 -type f ! -name WINDOWS.sha256 -printf '%P\0' | sort -z | xargs -0 sha256sum > WINDOWS.sha256)
overlap=$((WINDOW_SEC-STEP_SEC))
echo "PREPARED H rolling windows=$count radius_sec=$RADIUS_SEC window_sec=$WINDOW_SEC step_sec=$STEP_SEC overlap_sec=$overlap source=$SOURCE companion=$COMPANION out=$OUT"
