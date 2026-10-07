#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEB=""
REXX_BIN="${REXX_BIN:-}"

usage() {
  echo "usage: $0 [--deb /path/to/oorexx.deb] [--rexx /path/to/rexx]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deb)
      DEB="${2:-}"
      shift 2
      ;;
    --rexx)
      REXX_BIN="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

for command_name in unzip zip python3; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "MISSING: $command_name" >&2
    exit 3
  }
done

WORK_DIR="$(mktemp -d /tmp/oorexx-spreadsheet-qualification.XXXXXX)"
cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

DEPENDENCY_ZIP="$ROOT/deps/oorexx_intention_service_v0.1-dev9.zip"
[[ -f "$DEPENDENCY_ZIP" ]] || {
  echo "MISSING dependency: $DEPENDENCY_ZIP" >&2
  exit 4
}
unzip -q "$DEPENDENCY_ZIP" -d "$WORK_DIR/intention_service"
INTENTION_ROOT="$(find "$WORK_DIR/intention_service" -maxdepth 4 -type f -name IntentionService.cls -printf '%h\n' | head -1)"
[[ -n "$INTENTION_ROOT" ]] || {
  echo "Could not locate IntentionService.cls in pinned dependency." >&2
  exit 4
}

if [[ -n "$DEB" ]]; then
  command -v dpkg-deb >/dev/null 2>&1 || {
    echo "MISSING: dpkg-deb" >&2
    exit 3
  }
  [[ -f "$DEB" ]] || {
    echo "MISSING DEB: $DEB" >&2
    exit 4
  }
  dpkg-deb -x "$DEB" "$WORK_DIR/oorexx"
  REXX_BIN="$WORK_DIR/oorexx/usr/local/bin/rexx"
  export LD_LIBRARY_PATH="$WORK_DIR/oorexx/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

if [[ -z "$REXX_BIN" ]]; then
  REXX_BIN="$(command -v rexx || true)"
fi
[[ -n "$REXX_BIN" && -x "$REXX_BIN" ]] || {
  echo "No executable ooRexx interpreter found." >&2
  exit 5
}

export REXX_PATH="$ROOT/src:$INTENTION_ROOT${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' "=== ooRexx runtime ==="
"$REXX_BIN" -v
printf '%s\n' "=== pinned Intention Service ==="
printf '%s\n' "$INTENTION_ROOT"
printf '%s\n' "=== regenerate package fixtures ==="
python3 "$ROOT/tests/fixtures/make_fixtures.py"

printf '%s\n' "=== unit/contract tests ==="
for test_file in \
  "$ROOT/tests/test_readers.rex" \
  "$ROOT/tests/test_relations.rex" \
  "$ROOT/tests/test_intentions.rex" \
  "$ROOT/tests/test_interchange.rex"
do
  printf '%s\n' "--- $(basename "$test_file")"
  (cd "$ROOT/tests" && "$REXX_BIN" "$(basename "$test_file")")
done

printf '%s\n' "=== end-to-end XLSX intention probes ==="
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.xlsx" "show customers in Rochdale"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.xlsx" "find type hazards"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.xlsx" "find formulas"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.xlsx" "list relationships"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.xlsx" "show orders for customers in Rochdale"

printf '%s\n' "=== end-to-end ODS intention probes ==="
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.ods" "show customers in Rochdale"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.ods" "total credit limit customers"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/nasty.ods" "show orders for customers in Rochdale"

printf '%s\n' "=== multi-region XLSX intention probes ==="
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.xlsx" "what tables"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.xlsx" "show customers in Rochdale"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.xlsx" "show orders for customers in Rochdale"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.xlsx" "find type hazards"

printf '%s\n' "=== multi-region ODS intention probes ==="
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.ods" "what tables"
"$REXX_BIN" "$ROOT/examples/spreadsheet_chat.rex" "$ROOT/tests/fixtures/regions.ods" "show orders for customers in Rochdale"

printf '%s\n' "=== environment qualification PASS ==="
