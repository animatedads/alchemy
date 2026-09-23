#!/usr/bin/env bash
set -euo pipefail
# Detect the characteristic CCTV alarm on an ORIGINAL/unamplified PCM fixture.
# Detection is deliberately conservative: a frame must approach full scale AND
# sit well above the robust RMS baseline. Nearby hot frames are clustered.
# Output intervals are source-local seconds and preserve the original timeline.
IN=${1:?usage: detect_cctv_alarm.sh INPUT.wav OUTPUT.tsv}
OUT=${2:?usage: detect_cctv_alarm.sh INPUT.wav OUTPUT.tsv}
PEAK_DB=${CCTV_ALARM_PEAK_DB:--0.20}
RMS_DELTA_DB=${CCTV_ALARM_RMS_DELTA_DB:-12.0}
MERGE_GAP_SEC=${CCTV_ALARM_MERGE_GAP_SEC:-1.25}
MIN_HOT_FRAMES=${CCTV_ALARM_MIN_HOT_FRAMES:-4}
GUARD_SEC=${CCTV_ALARM_GUARD_SEC:-0.25}
command -v ffmpeg >/dev/null 2>&1 || { echo 'ffmpeg is required' >&2; exit 2; }
command -v awk >/dev/null 2>&1 || { echo 'awk is required' >&2; exit 2; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
meta="$tmp/astats.txt"; frames="$tmp/frames.tsv"; rmsvals="$tmp/rms.txt"
ffmpeg -nostdin -hide_banner -loglevel error -i "$IN" \
  -af "astats=metadata=1:reset=1,ametadata=print:file=$meta" -f null -
# Extract one line per decoder frame: start_sec peak_dbfs rms_dbfs.
awk '
  /^frame:/ {
    if (have) print t "\t" peak "\t" rms;
    have=1; t=""; peak=""; rms="";
    if (match($0,/pts_time:[^ ]+/)) { x=substr($0,RSTART+9,RLENGTH-9); t=x+0; }
    next
  }
  /^lavfi\.astats\.Overall\.Peak_level=/ { sub(/^[^=]*=/,""); peak=$0+0; next }
  /^lavfi\.astats\.Overall\.RMS_level=/  { sub(/^[^=]*=/,""); rms=$0+0; next }
  END { if (have) print t "\t" peak "\t" rms }
' "$meta" | awk -F '\t' 'NF==3 && $2==$2 && $3==$3 {print}' > "$frames"
[[ -s "$frames" ]] || { echo "FAIL: no astats frames from $IN" >&2; exit 4; }
awk -F '\t' '{print $3}' "$frames" | sort -n > "$rmsvals"
count=$(wc -l < "$rmsvals")
if (( count % 2 )); then
  baseline=$(sed -n "$((count/2+1))p" "$rmsvals")
else
  a=$(sed -n "$((count/2))p" "$rmsvals"); b=$(sed -n "$((count/2+1))p" "$rmsvals")
  baseline=$(awk -v a="$a" -v b="$b" 'BEGIN{printf "%.9f",(a+b)/2}')
fi
# Frame spacing is normally 1024/16000=.064 s; infer it so this remains correct
# if ffmpeg changes audio frame size.
frame_sec=$(awk -F '\t' 'NR==1{p=$1;next} {d=$1-p;if(d>0){print d;exit}}' "$frames")
[[ -n "$frame_sec" ]] || frame_sec=0.064
mkdir -p "$(dirname -- "$OUT")"
{
  printf '# schema=cctv.alarm.exclusion/1\n'
  printf '# detector=original-near-fullscale-cluster\n'
  printf '# source=%s\n' "$(basename -- "$IN")"
  printf '# baseline_rms_dbfs=%s peak_threshold_dbfs=%s rms_delta_db=%s merge_gap_sec=%s min_hot_frames=%s guard_sec=%s\n' "$baseline" "$PEAK_DB" "$RMS_DELTA_DB" "$MERGE_GAP_SEC" "$MIN_HOT_FRAMES" "$GUARD_SEC"
  printf 'start_sec\tend_sec\treason\tprovenance\thot_frames\tpeak_dbfs_max\trms_dbfs_max\n'
  awk -F '\t' -v peakthr="$PEAK_DB" -v bas="$baseline" -v delta="$RMS_DELTA_DB" -v gap="$MERGE_GAP_SEC" -v minhot="$MIN_HOT_FRAMES" -v guard="$GUARD_SEC" -v fs="$frame_sec" '
    function flush(    s,e) {
      if (hot >= minhot) {
        s=start-guard; if(s<0)s=0; e=last+fs+guard;
        printf "%.6f\t%.6f\tcctv_alarm\tauto:original-near-fullscale-cluster\t%d\t%.6f\t%.6f\n",s,e,hot,maxpeak,maxrms;
      }
      active=0; hot=0; start=last=maxpeak=maxrms=0;
    }
    {
      t=$1+0; p=$2+0; r=$3+0;
      ishot=(p>=peakthr && r>=bas+delta);
      if (!ishot) next;
      if (!active) {active=1; start=t; last=t; hot=1; maxpeak=p; maxrms=r; next}
      if (t-last<=gap) {last=t; hot++; if(p>maxpeak)maxpeak=p; if(r>maxrms)maxrms=r; next}
      flush(); active=1; start=t; last=t; hot=1; maxpeak=p; maxrms=r;
    }
    END { if(active) flush() }
  ' "$frames"
} > "$OUT"
intervals=$(awk -F '\t' '!/^#/ && $1!="start_sec" {n++} END{print n+0}' "$OUT")
printf 'CCTV_ALARM_SCAN source=%s baseline_rms_dbfs=%s intervals=%s manifest=%s\n' "$(basename -- "$IN")" "$baseline" "$intervals" "$OUT"
