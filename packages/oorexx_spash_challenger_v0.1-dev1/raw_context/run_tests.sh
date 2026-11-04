#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" tests/make_fixture.rex GOOD
"$REXX_BIN" tools/spash_raw_visual_stream.rex tests/stream_GOOD.samples.tsv tests/stream_GOOD.run.tsv tests/stream_GOOD.windows.tsv
"$REXX_BIN" tests/check_windows.rex
REXX_PATH="$PWD/tests:$REXX_PATH" "$REXX_BIN" tests/check_strata_storage.rex
for bad in BAD_PTS BAD_SOURCE BAD_ORDER; do
  "$REXX_BIN" tests/make_fixture.rex "$bad"
  rm -f "tests/stream_${bad}.windows.tsv" "tests/stream_${bad}.windows.tsv.INCOMPLETE"
  if "$REXX_BIN" tools/spash_raw_visual_stream.rex "tests/stream_${bad}.samples.tsv" "tests/stream_${bad}.run.tsv" "tests/stream_${bad}.windows.tsv" > /dev/null 2>&1; then
    echo "FAIL: malformed ${bad} admitted" >&2
    exit 1
  fi
  test ! -e "tests/stream_${bad}.windows.tsv" || { echo "FAIL invalid source produced final view"; exit 1; }
  echo "PASS malformed ${bad} rejected without published view"
done
