#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
if [[ -z "${INTENTION_SERVICE_ROOT:-}" ]]; then
  if [[ -f "$ROOT/vendor/intention/IntentionService.cls" ]]; then
    INTENTION_SERVICE_ROOT="$ROOT/vendor/intention"
  else
    INTENTION_SERVICE_ROOT="$(cd "$ROOT/.." && pwd)/oorexx_intention_service"
  fi
fi
if [[ -f "$INTENTION_SERVICE_ROOT/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT"
elif [[ -f "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
else
  echo "missing Intention Service dependency under $INTENTION_SERVICE_ROOT" >&2
  exit 2
fi
export REXX_PATH="$ROOT/src:$INTENTION_SRC:$INTENTION_SRC/nlp${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_font_manager.rex"
"$REXX_BIN" "$ROOT/tests/test_font_intentions.rex"
"$REXX_BIN" "$ROOT/tests/test_fontconfig_live.rex"
"$REXX_BIN" "$ROOT/tests/test_metrics_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_subset_live.rex" "${TMPDIR:-/tmp}/oorexx-font-subset-test.woff2"
"$REXX_BIN" "$ROOT/tests/test_glyphs_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_fallback_runs_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_required_format_fallback_live.rex" "$ROOT/tools/fonttools_service.py"
"$REXX_BIN" "$ROOT/tests/test_ttc_subset_live.rex" "$OUTDIR/ttc-subset.otf"
"$REXX_BIN" "$ROOT/tests/test_unicode_subset_live.rex" "$ROOT/tools/fonttools_service.py" "${PYFTSUBSET:-pyftsubset}" "${TMPDIR:-/tmp}/oorexx-font-unicode-subset.ttf"
