#!/bin/sh
set -eu
if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "usage: $0 FC|FD START_SERIAL END_SERIAL OUT.f32 [CORPUS_BASE] [FILE_EDGE_CALIBRATION.tsv]" >&2
  exit 2
fi
feed=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
start=$2; end=$3; out=$4
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
BASE=${5:-"$HOME/fcpaphos_originals/20231009_20231010"}
EDGE_MAP=${6:-${AUDIO_V9_FILE_EDGE_CALIBRATION:-}}
case "$feed" in fc) dir="$BASE/camera_fc";; fd) dir="$BASE/camera_fd";; *) echo "FAIL feed must be FC/FD" >&2; exit 2;; esac
[ -d "$dir" ] || { echo "FAIL source root missing: $dir" >&2; exit 2; }
command -v ffmpeg >/dev/null 2>&1 || { echo "FAIL ffmpeg missing" >&2; exit 2; }
TMP=${TMPDIR:-/tmp}/av9_decode_$$
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP" "$(dirname "$out")"
plan="$TMP/plan.tsv"
report="$out.decode.tsv"
if [ -n "$EDGE_MAP" ]; then
  "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_source_interval.rex" "$feed" "$start" "$end" "$EDGE_MAP" > "$plan"
else
  "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_source_interval.rex" "$feed" "$start" "$end" > "$plan"
fi
: > "$out"
printf 'feed\tfile\tnominal_source_start\teffective_source_start_sample\tslice_start_sample\tslice_end_sample\toffset_samples\texpected_samples\tcorrection_samples\tedge_status\taction\toriginal_bytes\tfinal_bytes\n' > "$report"
tail -n +2 "$plan" | while IFS="$(printf '\t')" read -r f name nominal effective slice_start slice_end offset_samples expected_samples correction edge_status; do
  [ "$f" = "$feed" ] || { echo "FAIL planner feed mismatch" >&2; exit 2; }
  src="$dir/$name"; [ -f "$src" ] || { echo "FAIL source missing: $src" >&2; exit 2; }
  part="$TMP/part_${slice_start}.f32"
  end_samples=$((offset_samples+expected_samples))
  # Semantic authority is canonical sample index after deterministic mono/8k conversion.
  # A measured dev6 calibration map changes the file hand-off point; any remaining short/long
  # decode is retained in the report and normalized only to preserve fixed worker geometry.
  ffmpeg -nostdin -v error -i "$src" -map 0:a:0 \
    -af "aformat=channel_layouts=mono,aresample=8000,atrim=start_sample=${offset_samples}:end_sample=${end_samples},asetpts=PTS-STARTPTS" \
    -c:a pcm_f32le -f f32le -y "$part"
  norm=$("$ROOT/tools/normalize_f32_geometry.sh" "$part" "$expected_samples")
  action=$(printf '%s' "$norm" | sed -n 's/.*action=\([^[:space:]]*\).*/\1/p')
  original=$(printf '%s' "$norm" | sed -n 's/.*original_bytes=\([0-9]*\).*/\1/p')
  final=$(printf '%s' "$norm" | sed -n 's/.*final_bytes=\([0-9]*\).*/\1/p')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$feed" "$name" "$nominal" "$effective" "$slice_start" "$slice_end" "$offset_samples" "$expected_samples" "$correction" "$edge_status" "$action" "$original" "$final" >> "$report"
  cat "$part" >> "$out"
done
expected=$(((end-start) * 8000 * 4)); got=$(stat -c %s "$out")
[ "$got" -eq "$expected" ] || { echo "FAIL interval decode expected_bytes=$expected got=$got" >&2; exit 2; }
echo "PASS decode feed=$feed start=$start end=$end samples=$((got/4)) out=$out report=$report"
