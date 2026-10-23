#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OOREXX_ROOT="${OOREXX_ROOT:-}"
if [[ -n "$OOREXX_ROOT" ]]; then
  REXX="$OOREXX_ROOT/usr/local/bin/rexx"
  REXXC="$OOREXX_ROOT/usr/local/bin/rexxc"
else
  REXX="$(command -v rexx)"
  REXXC="$(command -v rexxc)"
fi
[[ -x "$REXX" ]] || { echo "FAIL: rexx not found" >&2; exit 2; }
export LD_LIBRARY_PATH="${OOREXX_ROOT:+$OOREXX_ROOT/usr/local/lib:}${LD_LIBRARY_PATH:-}"
export PATH="${OOREXX_ROOT:+$OOREXX_ROOT/usr/local/bin:}$PATH"
export REXX_PATH="$ROOT/src:$ROOT/deps/instrumentation_intentions/src:$ROOT/deps/instrumentation_mesh/src:$ROOT/deps/notnotes_app/src:$ROOT/deps/notnotes_app/vendor/notnotes:$ROOT/deps/notnotes_app/vendor/nosql:$ROOT/deps/notnotes_app/vendor/pdf/src:$ROOT/deps/notnotes_app/vendor/cliui/rexx:$ROOT/deps/notnotes_intentions:$ROOT/deps/intention_service/src:$ROOT/deps/intention_service/src/nlp:${REXX_PATH:-}"

if [[ -n "$OOREXX_ROOT" ]]; then
  CLEAN_PATH="$OOREXX_ROOT/usr/local/bin:/usr/local/bin:/usr/bin:/bin"
  CLEAN_LD="$OOREXX_ROOT/usr/local/lib"
else
  CLEAN_PATH="/usr/local/bin:/usr/bin:/bin"
  CLEAN_LD="${LD_LIBRARY_PATH:-}"
fi

echo "== interpreter =="
"$REXX" -v | head -3

echo "== compile Initech help desk =="
"$REXXC" "$ROOT/src/InitechHelpDesk.cls" >/dev/null
"$REXXC" "$ROOT/src/InitechHelpDeskApiClientLLM.cls" >/dev/null

tmp="$(mktemp -d)"
retainedTmp="$(mktemp -d)"
trap 'rm -rf "$tmp" "$retainedTmp"' EXIT

echo "== retained Mini NotNotes authority slice =="
(
  cd "$ROOT/deps/notnotes_app"
  export REXX_HOME="${OOREXX_ROOT:+$OOREXX_ROOT/usr/local}"
  export REXX_BIN="$REXX"
  for test in tests/test_mini_notes.rex tests/test_query_guard.rex tests/test_tps_designer.rex tests/test_semantic_application_projection.rex tests/test_many_document_references.rex tests/test_instrumentation_mesh.rex tests/test_nosql_backend.rex; do
    testRoot="$retainedTmp/app-$(basename "$test" .rex)"
    env -i \
      PATH="$CLEAN_PATH" \
      LD_LIBRARY_PATH="$CLEAN_LD" \
      REXX_PATH="$REXX_PATH" \
      MININOTES_TEST_ROOT="$testRoot" \
      MININOTES_DB_ROOT="$testRoot" \
      "$REXX" "$test"
  done
)
echo "PASS retained Mini NotNotes TPS/document/NoSQL authority slice"

echo "== current Instrumentation Mesh / read-only intention specialist =="
(
  cd "$ROOT/deps/instrumentation_mesh"
  env -i PATH="$CLEAN_PATH" LD_LIBRARY_PATH="$CLEAN_LD" REXX_PATH="$REXX_PATH" "$REXX" tests/test_instrumentation_mesh.rex
  env -i PATH="$CLEAN_PATH" LD_LIBRARY_PATH="$CLEAN_LD" REXX_PATH="$REXX_PATH" "$REXX" tests/test_publication_collector.rex
)
(
  cd "$ROOT/deps/instrumentation_intentions/tests"
  env -i PATH="$CLEAN_PATH" LD_LIBRARY_PATH="$CLEAN_LD" REXX_PATH="$REXX_PATH" "$REXX" test_instrumentation_intentions.rex
)
echo "PASS current instrumentation authority/specialist slice"

cp -a "$ROOT/data/mininotes" "$tmp/mininotes-success"

echo "== two-tier help desk =="
(
  cd "$ROOT/deps/notnotes_app"
  TEST_DATA_ROOT="$tmp/mininotes-success" "$REXX" "$ROOT/tests/test_helpdesk.rex"
)

echo "PASS Initech NotNotes help-desk environment qualification"
