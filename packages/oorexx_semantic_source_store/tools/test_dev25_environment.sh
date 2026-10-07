#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx || true)}"
INTENTION_SRC="${INTENTION_SERVICE_SRC:-}"

if [[ -z "$REXX_BIN" || ! -x "$REXX_BIN" ]]; then
  echo "FAIL: ooRexx rexx executable not found; set REXX_BIN" >&2
  exit 2
fi
if [[ -z "$INTENTION_SRC" || ! -f "$INTENTION_SRC/IntentionService.cls" ]]; then
  echo "FAIL: set INTENTION_SERVICE_SRC to oorexx_intention_service_v0.1-dev11/src" >&2
  exit 2
fi

export REXX_PATH="$ROOT/src:$INTENTION_SRC:${REXX_PATH:-}"
cd "$ROOT/test"

"$REXX_BIN" oorexx_structural_adapter_test.rex
"$REXX_BIN" oorexx_structural_tree_test.rex
"$REXX_BIN" bulk_importer_test.rex
"$REXX_BIN" intention_service_test.rex
"$REXX_BIN" language_service_test.rex
python3 structural_import_contract_test.py
python3 examiner_intention_contract_test.py
python3 examiner_rendered_ui_test.py
python3 examiner_security_contract_test.py
python3 bulk_package_materialisation_contract_test.py

echo "SSC DEV25 ENVIRONMENT QUALIFICATION: PASS"
