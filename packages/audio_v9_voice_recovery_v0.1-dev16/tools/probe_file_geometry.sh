#!/bin/sh
set -eu
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
  echo "usage: $0 FC|FD CORPUS_BASE OUT.tsv [SAMPLE_RATE]" >&2
  exit 2
fi
feed=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
BASE=$2; OUT=$3; SR=${4:-8000}
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
case "$feed" in fc) dir="$BASE/camera_fc"; list="$ROOT/campaign/FC_FILES.txt";; fd) dir="$BASE/camera_fd"; list="$ROOT/campaign/FD_FILES.txt";; *) echo 'FAIL feed must be FC/FD' >&2; exit 2;; esac
command -v ffmpeg >/dev/null 2>&1 || { echo 'FAIL ffmpeg missing' >&2; exit 2; }
TMP=${TMPDIR:-/tmp}/av9_edge_geometry_$$
trap 'rm -rf "$TMP"' EXIT INT TERM
mkdir -p "$TMP" "$(dirname "$OUT")"
raw="$TMP/raw.tsv"
printf 'feed\tleft_file\tright_file\tsample_rate\tdecoded_samples\n' > "$raw"
prev=''
while IFS= read -r name || [ -n "$name" ]; do
  [ -n "$name" ] || continue
  if [ -n "$prev" ]; then
    left="$dir/$prev"
    [ -f "$left" ] || { echo "FAIL source missing: $left" >&2; exit 2; }
    log="$TMP/ashowinfo.log"
    : > "$log"
    ffmpeg -nostdin -v info -i "$left" -map 0:a:0 \
      -af "aformat=channel_layouts=mono,aresample=${SR},ashowinfo" -f null - >/dev/null 2>"$log"
    decoded=$(awk 'BEGIN{s=0} /Parsed_ashowinfo/ {for(i=1;i<=NF;i++) if($i ~ /^nb_samples:/){split($i,a,":"); s+=a[2]}} END{printf "%.0f\n",s}' "$log")
    case "$decoded" in ''|*[!0-9]*) echo "FAIL could not count decoded samples: $left" >&2; exit 2;; esac
    printf '%s\t%s\t%s\t%s\t%s\n' "$feed" "$prev" "$name" "$SR" "$decoded" >> "$raw"
  fi
  prev=$name
done < "$list"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/geometry_observations_from_counts.rex" "$raw" "$OUT"
