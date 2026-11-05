#!/bin/sh
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$root/tests"
runner=${REXX:-rexx}
for test in test_sparse_mp4.rex test_seek_index.rex test_mp4_sample_table.rex test_mp4_co64.rex test_mp4_elst.rex test_mp4_track_elst.rex test_media_cache_1gb.rex
do
  printf '%s\n' "=== $test ==="
  "$runner" "$test"
done
printf '%s\n' 'Completed all seven ooRexx metadata/range tests'
