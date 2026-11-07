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
else
  printf '%s\n' 'TS resident-file regression SKIPPED (set MEDIA_TS_TEST_FILE)'
fi
printf '%s\n' 'Completed ooRexx metadata/range tests'
