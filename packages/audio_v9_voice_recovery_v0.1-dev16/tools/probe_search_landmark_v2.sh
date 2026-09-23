#!/bin/sh
set -eu
if [ "$#" -lt 2 ] || [ "$#" -gt 5 ]; then
  echo 'usage: probe_search_landmark.sh LANDMARK_ID OUT_DIR [CORPUS_BASE] [PRE_SECONDS] [POST_SECONDS]' >&2
  exit 2
fi
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
ID=$1; OUT=$2; BASE=${3:-"$HOME/fcpaphos_originals/20231009_20231010"}; PRE=${4:-60}; POST=${5:-240}
mkdir -p "$OUT"
PLAN="$OUT/LANDMARK_PLAN.tsv"
set -- $("$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_search_landmark.rex" "$ID" "$PLAN" "$PRE" "$POST")
START=$1; END=$2; ANCHOR=$3; FEED=$4
[ "$END" -gt "$START" ] || { echo 'FAIL landmark probe interval must be positive' >&2; exit 2; }
"$ROOT/tools/verify_corpus.sh" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fc "$START" "$END" "$OUT/fc.f32" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fd "$START" "$END" "$OUT/fd.f32" "$BASE" >/dev/null
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/scan_loud_echo_events_v2.rex" \
  "$OUT/fc.f32" "$OUT/fd.f32" "$OUT/LOUD_EVENT_ECHOES.tsv" 0.001 6 120 6 4 "$START" 0.70
{
  printf 'schema\taudio.v9.voice-recovery.search-landmark-probe/1\n'
  printf 'landmark_id\t%s\n' "$ID"
  printf 'feed\t%s\n' "$FEED"
  printf 'start_serial\t%s\n' "$START"
  printf 'anchor_serial\t%s\n' "$ANCHOR"
  printf 'end_serial\t%s\n' "$END"
  printf 'pre_seconds\t%s\n' "$PRE"
  printf 'post_seconds\t%s\n' "$POST"
  printf 'corpus_base\t%s\n' "$BASE"
  printf 'semantic_note\tlandmark is user-annotated speech evidence; loud-echo rows are auxiliary and absence is not negative speech evidence\n'
} > "$OUT/LANDMARK_PROBE.meta.tsv"
sha256sum "$PLAN" "$OUT/fc.f32" "$OUT/fd.f32" "$OUT/LOUD_EVENT_ECHOES.tsv" "$OUT/LANDMARK_PROBE.meta.tsv" > "$OUT/SHA256SUMS"
echo "PASS landmark probe id=$ID start=$START anchor=$ANCHOR end=$END out=$OUT"
