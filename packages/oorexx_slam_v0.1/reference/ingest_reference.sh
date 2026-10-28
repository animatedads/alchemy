#!/bin/sh
# Ingest the ooRexx reference (rexxref) fact files into ONE SLAM database, with SLAM's own reader.
# Architecture: Tom Dyer.  Code and translation: Claude (Opus 5.5), 2026-10-28.
# Usage: sh reference/ingest_reference.sh DB
#   run from packages/oorexx_slam_v0.1, with the same environment as run_tests.sh
#   (LD_LIBRARY_PATH holding librexxsql.so, REXX_PATH holding src/, vendor/rx2cpp and the Rexx/SQL backend).
# Order matters: each file may use only words the files before it define.
set -eu
DB=${1:?usage: sh reference/ingest_reference.sh DB}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
cd "$ROOT"
rexx bin/slam.rex corpus "$DB" corpus/circular_corpus_v2.csv
rexx bin/slam.rex read "$DB" README_SLAM.md
for f in "$HERE"/[0-9][0-9]_*.md; do
  echo "== $(basename "$f")"
  out=$(rexx bin/slam.rex facts "$DB" "$f")
  echo "$out"
  case "$out" in
    *"not words i know"*) echo "STOP: SLAM can not read $(basename "$f")"; exit 1 ;;
  esac
done
rexx bin/slam.rex stats "$DB"
