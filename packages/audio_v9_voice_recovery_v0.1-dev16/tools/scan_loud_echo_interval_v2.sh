#!/bin/sh
set -eu
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo 'usage: scan_loud_echo_interval_v2.sh "START" "END" OUT.tsv [CORPUS_BASE]' >&2
  exit 2
fi
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
START_TEXT=$1; END_TEXT=$2; OUT=$3; BASE=${4:-"$HOME/fcpaphos_originals/20231009_20231010"}
start=$($ROOT/tools/run_rexx_pinned.sh "$ROOT/tools/wallclock_to_serial.rex" "$START_TEXT")
end=$($ROOT/tools/run_rexx_pinned.sh "$ROOT/tools/wallclock_to_serial.rex" "$END_TEXT")
[ "$end" -gt "$start" ] || { echo 'FAIL echo v2 interval must be positive' >&2; exit 2; }
span=$((end-start)); [ "$span" -le 600 ] || { echo 'FAIL diagnostic echo v2 interval is bounded to 600 seconds' >&2; exit 2; }
dir=$(dirname "$OUT"); mkdir -p "$dir"; work="$dir/.av9_loud_echo_v2.$$"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT HUP INT TERM
"$ROOT/tools/verify_corpus.sh" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fc "$start" "$end" "$work/fc.f32" "$BASE" >/dev/null
"$ROOT/tools/decode_serial_interval.sh" fd "$start" "$end" "$work/fd.f32" "$BASE" >/dev/null
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/scan_loud_echo_events_v2.rex" "$work/fc.f32" "$work/fd.f32" "$OUT" 0.001 6 120 6 4 "$start" 0.70
printf 'schema\taudio.v9.voice-recovery.loud-echo-window/2\nstart\t%s\nend\t%s\nstart_serial\t%s\nend_serial\t%s\nmin_abs_peak\t0.001\nmin_ratio\t6\nradius_ms\t4\nstrong_score\t0.70\n' "$START_TEXT" "$END_TEXT" "$start" "$end" > "$OUT.meta.tsv"
echo "PASS loud echo v2 interval start=$START_TEXT end=$END_TEXT out=$OUT"
