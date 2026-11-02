#!/bin/sh
# Decode ONLY via ffmpeg; native ooRexx does all structural patch comparison.
# Usage: run_stream_stability.sh stream1_any.ext stream2_any.ext stream3_any.ext outputdir
set -eu
if [ "$#" -ne 4 ]; then echo 'Usage: run_stream_stability.sh stream1 stream2 stream3 outdir' >&2; exit 2; fi
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
outdir=$4
mkdir -p "$outdir/frames"
: "${REXX_BIN:=rexx}"
command -v ffmpeg >/dev/null || { echo 'ffmpeg missing' >&2; exit 2; }
for n in 1 2 3; do
  input=$1
  shift
  ffmpeg -nostdin -hide_banner -loglevel error -y -i "$input" \
    -vf 'fps=1/15,scale=320:180,format=gray' -an -pix_fmt gray -f rawvideo \
    "$outdir/frames/stream${n}_320x180_gray.raw"
  size=$(wc -c < "$outdir/frames/stream${n}_320x180_gray.raw")
  if [ "$size" -ne 230400 ]; then echo "frame count/geometry mismatch stream${n} bytes=$size" >&2; exit 2; fi
done
export REXX_PATH="$here${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$here/test_stream_stability.rex"
"$REXX_BIN" "$here/test_clock_evidence.rex"
"$REXX_BIN" "$here/measure_stream_stability.rex" "$outdir/frames" > "$outdir/stream_stability.tsv"
echo "OUTPUT $outdir/stream_stability.tsv"