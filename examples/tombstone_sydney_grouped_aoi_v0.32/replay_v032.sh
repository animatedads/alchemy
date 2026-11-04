#!/bin/bash
# Replay native grouped V5V lookup from four original H.264 MPEG-TS uploads.
# Processing source: real V5V Vision five-bit packed receipts; no OpenCV tracking.
# Pixel accuracy: decoded native source RGB24 frames and native C crop/motion tools.
set -euo pipefail
if [ "$#" -ne 6 ];then echo 'Usage: replay_v032.sh CRUISE_CAM2.mkv CRUISE_CAM3.mkv NORMAL_CAM2.mkv NORMAL_CAM3.mkv V031_FIXTURES_DIR OUT_DIR' >&2;exit 2;fi
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
inputs=("$1" "$2" "$3" "$4")
fixtures=$5;mkdir -p "$6";out=$(cd "$6" && pwd)
mkdir -p "$out/frames" "$out/crops" "$out/results"
[ "$out" != "$root" ] || { echo 'Do not overwrite reference evidence' >&2;exit 3; }
: "${REXX_BIN:=rexx}";command -v "$REXX_BIN" >/dev/null || { echo 'native ooRexx not found' >&2;exit 4; }
for exe in v5v_merge_static_v032 crop_raw rgb_motion_structure ship_structure_native;do
 case "$exe" in v5v_merge_static_v032) source="$root/source/v5v_merge_static_v032.c";;*) source="$root/source/${exe}.c";;esac
 gcc -O2 -Wall -Wextra -Werror -std=c11 "$source" -lm -o "$out/$exe"
done
order=(cruise_cam2 cruise_cam3 baseline_cam2 baseline_cam3)
sha_expected=(6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830 c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0 58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d)
for idx in 0 1 2 3;do
 stem=${order[$idx]};video=${inputs[$idx]};expected=${sha_expected[$idx]}
 [ -f "$video" ] || { echo "Missing original $video" >&2;exit 5; }
 sha=$(sha256sum "$video" | awk '{print $1}')
 [ "$sha" = "$expected" ] || { echo "Original source SHA mismatch $stem" >&2;exit 6; }
 case "$stem" in *cam2) cam=2;srcw=1280;srch=720;;*) cam=3;srcw=640;srch=360;;esac
 "$out/v5v_merge_static_v032" "$fixtures/fixtures/$stem.nodes.psv" "$fixtures/fixtures/$stem.v5b" "$fixtures/fixtures/cam$cam.water_mask.psv" "$fixtures/evidence/${stem}_proposals.psv" "$out/results/${stem}_groups.psv" | tee "$out/results/${stem}.log"
 framesize=$((srcw*srch*3))
 ffmpeg -nostdin -v error -i "$video" -map 0:v:0 -an -vf "select='eq(n,150)+eq(n,300)+eq(n,450)+eq(n,600)+eq(n,750)+eq(n,900)+eq(n,1050)+eq(n,1200)+eq(n,1350)'" -fps_mode passthrough -pix_fmt rgb24 -f rawvideo -y "$out/frames/${stem}.all"
 [ "$(stat -c %s "$out/frames/${stem}.all")" -eq "$((9*framesize))" ] || { echo "Selected RGB frame count invalid: $stem" >&2;exit 7; }
 n=0
 for frame in 150 300 450 600 750 900 1050 1200 1350;do
  dd if="$out/frames/${stem}.all" of="$out/frames/${stem}_f${frame}.rgb" bs="$framesize" skip="$n" count=1 status=none
  n=$((n+1))
 done
 rm "$out/frames/${stem}.all"
done
first=1
: > "$out/results/all_groups.psv"
for stem in "${order[@]}";do
 if [ "$first" -eq 1 ];then cat "$out/results/${stem}_groups.psv" >> "$out/results/all_groups.psv";first=0;else tail -n +2 "$out/results/${stem}_groups.psv" >> "$out/results/all_groups.psv";fi
done
printf '%s\n' 'camera|period|source_sha256|frame|timestamp_seconds|group|member_ranks|members|lookup_x0|lookup_y0|lookup_x1|lookup_y1|bbox_cells|union_cells|unchanged_upper_cells|changing_upper_cells|changing_water_cells|provisional_landmark_overlap|static_review_state|source_x|source_y|width|height|rgb_sha256|bright|vertical_edge|both_changes|dynamic_bright|coherent_blocks|evidence_state' > "$out/results/grouped_crops_receipts.psv"
for stem in "${order[@]}";do
 case "$stem" in cruise_cam2) cam=2;period=cruise;factor=16;;cruise_cam3) cam=3;period=cruise;factor=8;;baseline_cam2) cam=2;period=baseline;factor=16;;baseline_cam3)cam=3;period=baseline;factor=8;;esac
 sw=$((80*factor));sh=$((45*factor));bytes=$((sw*sh*3))
 while IFS='|' read -r sha frame pts group ranks members x0 y0 x1 y1 area union prev saved stable moving water land hint state authority;do
  [ "$sha" = source_sha256 ] && continue
  [ "$state" = 'UNCLASSIFIED_GROUP' ] && [ "$authority" = 'OBSERVED_UNTESTED' ] || { echo 'Unqualified group' >&2;exit 8; }
  sx=$((x0*factor));sy=$((y0*factor));width=$(((x1-x0)*factor));height=$(((y1-y0)*factor))
  crop="$out/crops/${stem}_f${frame}_group${group}.rgb"
  "$out/crop_raw" "$out/frames/${stem}_f${frame}.rgb" "$sw" "$sh" "$sx" "$sy" "$width" "$height" "$crop" "$bytes"
  digest=$(sha256sum "$crop" | awk '{print $1}')
  structure=$("$out/ship_structure_native" "$crop" "$width" "$height")
  temporal=$("$out/rgb_motion_structure" "$out/frames/${stem}_f${frame}.rgb" "$out/frames/${stem}_f$((frame-150)).rgb" "$out/frames/${stem}_f$((frame-300)).rgb" "$sw" "$sh" "$sx" "$sy" "$width" "$height" "$bytes")
  IFS='|' read -r sv fw fh bright bright180 hedge vedge mean <<< "$structure"
  IFS='|' read -r tv change5 change10 both dynamic dynEdge allbright coherent totalBlocks <<< "$temporal"
  [ "$sv" = STRUCTURE_V1 ] && [ "$tv" = RGB_TEMPORAL_V1 ] || { echo 'native extraction failed' >&2;exit 9; }
  printf '%s\n' "$cam|$period|$sha|$frame|$pts|$group|$ranks|$members|$x0|$y0|$x1|$y1|$area|$union|$stable|$moving|$water|$land|$hint|$sx|$sy|$width|$height|$digest|$bright|$vedge|$both|$dynamic|$coherent|OBSERVED_UNTESTED" >> "$out/results/grouped_crops_receipts.psv"
 done < "$out/results/${stem}_groups.psv"
done
"$REXX_BIN" "$root/source/verify_grouped_v032.rex" "$fixtures/evidence" "$out/results/all_groups.psv" "$out/results/grouped_crops_receipts.psv"
cmp "$root/results/all_groups.psv" "$out/results/all_groups.psv"
cmp "$root/results/grouped_crops_receipts.psv" "$out/results/grouped_crops_receipts.psv"
echo 'SYDNEY V032 ORIGINAL FOUR-VIDEO REPLAY BYTE-IDENTICAL PASS'
