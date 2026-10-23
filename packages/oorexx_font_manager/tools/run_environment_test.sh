#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
: "${INTENTION_SERVICE_ROOT:=$(cd "$ROOT/.." && pwd)/oorexx_intention_service}"
[[ -f "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" ]] || {
  echo "missing dependency: $INTENTION_SERVICE_ROOT/src/IntentionService.cls" >&2
  exit 2
}
export REXX_PATH="$ROOT/src:$INTENTION_SERVICE_ROOT/src:$INTENTION_SERVICE_ROOT/src/nlp${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_font_manager.rex"
"$REXX_BIN" "$ROOT/tests/test_font_intentions.rex"
"$REXX_BIN" "$ROOT/tests/test_fontconfig_live.rex"
"$REXX_BIN" "$ROOT/tests/test_metrics_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_subset_live.rex" "${TMPDIR:-/tmp}/oorexx-font-subset-test.woff2"
"$REXX_BIN" "$ROOT/tests/test_glyphs_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_unicode_subset_live.rex" "$ROOT/tools/fonttools_service.py" "${PYFTSUBSET:-pyftsubset}" "${TMPDIR:-/tmp}/oorexx-font-unicode-subset.ttf"
