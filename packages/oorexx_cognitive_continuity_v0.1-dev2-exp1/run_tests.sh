#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXX:=rexx}"
: "${REXXC:=rexxc}"
export REXX_PATH="$HERE/src:$HERE/integration${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
if [ "${1:-}" = compile ]; then
  for f in src/*.cls integration/*.cls tests/*.rex tools/*.rex examples/*.rex; do "$REXXC" "$f" >/dev/null; done
  echo "PASS compile"
  exit 0
fi
for t in \
  tests/test_cognitive_continuity.rex \
  tests/test_jsonl_replay.rex \
  tests/test_llmpa_adapter.rex \
  tests/test_projection_and_feed.rex \
  tests/test_learning_queue.rex \
  tests/test_structured_bridge.rex \
  tests/test_schema_and_mcp.rex \
  tests/test_mcp_protocol.rex
do
  "$REXX" "$t"
done
