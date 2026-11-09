#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$root/tests"
runner=${REXX:-rexx}
for test in test_sparse_mp4.rex test_seek_index.rex test_mp4_sample_table.rex test_mp4_co64.rex test_mp4_elst.rex test_mp4_track_elst.rex test_media_cache_1gb.rex test_mp4_index_snapshot.rex
do
  printf '%s\n' "=== $test ==="
  "$runner" "$test"
done
if [ "${MEDIA_TS_TEST_FILE:-}" != "" ]; then
  printf '%s\n' '=== test_ts_contract.rex (resident MPEG-TS file) ==='
  "$runner" test_ts_contract.rex "$MEDIA_TS_TEST_FILE"
  printf '%s\n' '=== test_ts_hotseek_real.rex (persisted sidecar and bounded jumps) ==='
  "$runner" test_ts_hotseek_real.rex "$MEDIA_TS_TEST_FILE" "${MEDIA_TS_INDEX_DIR:-.}"
else
  printf '%s\n' 'TS resident-file regression SKIPPED (set MEDIA_TS_TEST_FILE)'
fi
if [ "${MEDIA_PNG_TESTS:-0}" = "1" ]; then
  mkdir -p out
  printf '%s\n' '=== test_png_channels.rex (native libpng plus exact alpha) ==='
  "$runner" test_png_channels.rex
fi
if [ "${MEDIA_H264_CHANNEL_TESTS:-0}" = "1" ]; then
  mkdir -p out
  printf '%s\n' '=== test_h264_rgb_planes.rex (shared planar raster output) ==='
  "$runner" test_h264_rgb_planes.rex
fi
if [ "${MEDIA_SCREENSHOT_ROOT:-}" != "" ]; then
  mkdir -p out
  printf '%s\n' '=== test_sydney_png_rgba.rex (local user screenshots) ==='
  "$runner" test_sydney_png_rgba.rex "$MEDIA_SCREENSHOT_ROOT" out
fi
if [ "${MEDIA_RASTER_DEV6_TESTS:-0}" = "1" ]; then
  echo "=== adaptive absolute subtraction dev6 tests ==="
  ./run_native_dev6.sh
fi
printf '%s\n' 'Completed ooRexx metadata/range tests'
