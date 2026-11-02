#!/bin/sh
# Real uploaded video sources only, uses original frame index and raw RGB24.
set -eu
[ "$#" -eq 3 ] || { echo 'Usage run_qualification.sh cruise.mkv normal.mkv out_dir' >&2; exit 2; }
cruise=$1;normal=$2;mkdir -p "$3";out=$(cd "$3" && pwd)
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
expectedCruise=c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e
expectedNormal=58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d
[ "$(sha256sum "$cruise" | awk '{print $1}')" = "$expectedCruise" ] || { echo 'cruise source SHA rejected' >&2; exit 3; }
[ "$(sha256sum "$normal" | awk '{print $1}')" = "$expectedNormal" ] || { echo 'normal source SHA rejected' >&2; exit 3; }
for src in "$cruise" "$normal";do
 [ "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate -of csv=p=0 "$src" | head -1)" = '640,360,30/1' ] || { echo 'source format changed' >&2; exit 3; }
done
for spec in "cruise:$cruise" "baseline:$normal";do
 name=${spec%%:*};src=${spec#*:}
 ffmpeg -nostdin -v error -i "$src" -map 0:v:0 -an -vf 'select=eq(n\,150)+eq(n\,450)+eq(n\,750)+eq(n\,900)+eq(n\,1050)+eq(n\,1350)+eq(n\,1650)' -fps_mode passthrough -pix_fmt rgb24 -f rawvideo -y "$out/$name.rgb"
done
cc -O2 -std=c11 -Wall -Wextra -Werror -o "$out/static_landmark_diff" "$root/static_landmark_diff.c"
"$out/static_landmark_diff" "$out/cruise.rgb" "$out/baseline.rgb" "$expectedCruise" "$expectedNormal" > "$out/anchor_receipts.psv"
: "${REXX_BIN:=rexx}"
REXX_PATH="$root${REXX_PATH:+:$REXX_PATH}" "$REXX_BIN" "$root/qualify_image_landmarks.rex" "$out/anchor_receipts.psv" "$out/occlusion_candidate.psv"
