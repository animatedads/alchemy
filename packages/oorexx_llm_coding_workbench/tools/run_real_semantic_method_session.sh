#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_ROOT:?set OOREXX_ROOT to the extracted ooRexx r13196 package root}"
: "${INTENTION_SERVICE_ROOT:?set INTENTION_SERVICE_ROOT to oorexx_intention_service_v0.1-dev9 root}"
: "${SEMANTIC_SOURCE_STORE_ROOT:?set SEMANTIC_SOURCE_STORE_ROOT to the Development Desk/Semantic Source Store root}"
: "${CODING_INTENTION_ROOT:?set CODING_INTENTION_ROOT to coding_intention_steps_v0.1-dev13 root}"
REXX="$OOREXX_ROOT/usr/local/bin/rexx"
REXXC="$OOREXX_ROOT/usr/local/bin/rexxc"
BIN="$OOREXX_ROOT/usr/local/bin"
LIB="$OOREXX_ROOT/usr/local/lib/ooRexx"
export LD_LIBRARY_PATH="$OOREXX_ROOT/usr/local/lib:${LD_LIBRARY_PATH:-}"
"$REXX" -v | head -1 | grep -q '5.3.0 r13196' || { "$REXX" -v; echo 'FAIL: ooRexx 5.3.0 r13196 required' >&2; exit 3; }

# Re-project the Coding Intention language knowledge so the live session cannot
# silently use a stale workbench catalogue.
CAT_TMP="$(mktemp)"
(
  export REXX_PATH="$CODING_INTENTION_ROOT:$BIN:$LIB"
  cd "$ROOT"
  "$REXX" tools/export_coding_intention_catalogue.rex "$CAT_TMP"
)
cmp -s "$CAT_TMP" "$ROOT/config/coding_intention_dev13_rexx_catalogue.json" || {
  echo 'FAIL: Coding Intention dev13 language/contract catalogue drift' >&2
  rm -f "$CAT_TMP"; exit 4
}
rm -f "$CAT_TMP"

export LLM_CODING_CATALOGUE="$ROOT/config/coding_intention_dev13_rexx_catalogue.json"
INT="$INTENTION_SERVICE_ROOT"
SSS="$SEMANTIC_SOURCE_STORE_ROOT"
export REXX_PATH="$ROOT/src:$ROOT/tests:$INT/src:$INT/src/nlp:$SSS/src:$SSS/test:$BIN:$LIB${REXX_PATH:+:$REXX_PATH}"

WORK="${LLM_CODING_WORK_ROOT:-$ROOT/.live-session}"
DB="$WORK/deskdb"
OUT="$WORK/generated_house.rex"
DRIVER="$WORK/generated_house_runtime.rex"
rm -rf "$WORK"; mkdir -p "$WORK"

"$REXXC" "$ROOT/tests/test_real_method_session.rex" >/dev/null
echo 'PASS rexxc tests/test_real_method_session.rex'
(
  cd "$ROOT/tests"
  "$REXX" test_real_method_session.rex "$DB" "$OUT"
)

"$REXXC" "$OUT" >/dev/null
echo 'PASS rexxc real-session materialised source'
cat > "$DRIVER" <<DRIVER_EOF
h=.House~new
if h~openDoor \\== .true then do; say 'FAIL first open'; exit 41; end
if h~openDoor \\== .false then do; say 'FAIL second open'; exit 42; end
say 'PASS real-session generated House runtime behaviour'
exit 0
::requires "$OUT"
DRIVER_EOF
"$REXXC" "$DRIVER" >/dev/null
"$REXX" "$DRIVER"
echo 'PASS real semantic method session environment qualification'
