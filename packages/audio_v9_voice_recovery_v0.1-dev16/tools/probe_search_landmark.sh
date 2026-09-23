#!/bin/sh
set -eu
if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  echo 'usage: probe_search_landmark.sh LANDMARK_ID OUT_DIR [CORPUS_BASE] [PRE_SECONDS] [POST_SECONDS]' >&2
  exit 2
fi
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ID=$1; OUT=$2; BASE=${3:-"$HOME/fcpaphos_originals/20231009_20231010"}
PRE=${4-}; POST=${5-}
mkdir -p "$OUT"
PLAN="$OUT/LANDMARK_PLAN.tsv"
if [ -n "$PRE" ] || [ -n "$POST" ]; then
  [ -n "$PRE" ] && [ -n "$POST" ] || { echo 'FAIL specify both PRE_SECONDS and POST_SECONDS, or neither' >&2; exit 2; }
  set -- $("$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_search_landmark.rex" "$ID" "$PLAN" "$PRE" "$POST")
else
  set -- $("$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_search_landmark.rex" "$ID" "$PLAN")
fi
START=$1; END=$2; ANCHOR=$3; FEED=$4; ANCHOR_MS=$5
[ "$END" -gt "$START" ] || { echo 'FAIL landmark probe interval must be positive' >&2; exit 2; }
"$ROOT/tools/verify_corpus.sh" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fc "$START" "$END" "$OUT/fc.f32" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fd "$START" "$END" "$OUT/fd.f32" "$BASE" >/dev/null
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/scan_loud_echo_events_v3.rex" \
  "$OUT/fc.f32" "$OUT/fd.f32" "$OUT/LOUD_EVENT_ECHOES_V3.tsv" 0.001 6 120 6 4 "$START" 0.70 6 80 3
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/summarize_search_landmark_v3.rex" \
  "$PLAN" "$OUT/LOUD_EVENT_ECHOES_V3.tsv" "$OUT/ANCHOR_EVENTS_V3.tsv" 2000
{
  printf 'schema\taudio.v9.voice-recovery.search-landmark-probe/2\n'
  printf 'landmark_id\t%s\n' "$ID"
  printf 'feed\t%s\n' "$FEED"
  printf 'start_serial\t%s\n' "$START"
  printf 'anchor_serial\t%s\n' "$ANCHOR"
  printf 'anchor_serial_ms\t%s\n' "$ANCHOR_MS"
  printf 'end_serial\t%s\n' "$END"
  printf 'corpus_base\t%s\n' "$BASE"
  printf 'scanner\tscan_loud_echo_events_v3.rex\n'
  printf 'prior_free_search_ms\t6..80\n'
  printf 'named_family_radius_ms\t4\n'
  printf 'cross_camera_radius_ms\t35; endpoint is censored when cross_boundary=1\n'
  printf 'anchor_summary_window_ms\t2000\n'
  printf 'semantic_note\tlandmark observation and audio-v3 evidence remain separate authorities; absence of loud-event rows is not negative speech evidence\n'
} > "$OUT/LANDMARK_PROBE.meta.tsv"
sha256sum "$PLAN" "$OUT/fc.f32" "$OUT/fd.f32" "$OUT/LOUD_EVENT_ECHOES_V3.tsv" "$OUT/ANCHOR_EVENTS_V3.tsv" "$OUT/LANDMARK_PROBE.meta.tsv" > "$OUT/SHA256SUMS"
echo "PASS landmark v3 probe id=$ID start=$START anchor=$ANCHOR anchor_ms=$ANCHOR_MS end=$END out=$OUT"
