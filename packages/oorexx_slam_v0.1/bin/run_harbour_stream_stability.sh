#!/bin/sh
# Repository runner: decode only with FFmpeg; fixed patch registration in native ooRexx.
# Usage: run_harbour_stream_stability.sh stream1 stream2 stream3 outputdir
set -eu
if [ "$#" -ne 4 ]; then echo 'Usage: run_harbour_stream_stability.sh stream1 stream2 stream3 outputdir' >&2; exit 2; fi
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)
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
  if [ "$size" -ne 230400 ]; then echo "frame count mismatch stream${n}, bytes=$size" >&2; exit 2; fi
done
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$root/tests/test_stream_stability.rex"
"$REXX_BIN" "$root/tests/test_clock_evidence.rex"
"$REXX_BIN" "$root/tests/measure_stream_stability.rex" "$outdir/frames" > "$outdir/stream_stability.tsv"
echo "OUTPUT $outdir/stream_stability.tsv"
