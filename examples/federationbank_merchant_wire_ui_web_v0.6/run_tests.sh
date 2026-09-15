#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
"$ROOT/tests/test_projection_shell.sh"
node --test "$ROOT/tests/test_workspace_context_echo.mjs"
"$ROOT/tests/test_preview_boundary.sh"
"$ROOT/tests/test_early_workspace.sh"
"$ROOT/tests/test_starter.sh"
if [[ -n "${FBM_REXX:-}" && -n "${WUI_BUILDER_SRC:-}" && -n "${WUI_SERVER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" && -n "${OOREXX_CRYPTO_SRC:-}" ]]; then
  export REXX_PATH="$ROOT/integration:$ROOT/tests:$WUI_BUILDER_SRC:$WUI_SERVER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$(dirname "$FBM_REXX")${REXX_PATH:+:$REXX_PATH}"
  "$FBM_REXX" "$ROOT/tests/test_wire_ui_compile.rex"
  "$FBM_REXX" "$ROOT/tests/test_precompiled_release.rex" "$ROOT/semantic/federationbank_merchant_operations_v0.6.json"
  (cd "$ROOT" && "$FBM_REXX" "$ROOT/tests/test_wire_ui_workspace.rex")
  (cd "$ROOT" && "$FBM_REXX" "$ROOT/tests/test_row_collection_contract.rex")
else
  echo 'Merchant semantic Wire UI tests: SKIP (set FBM_REXX/WUI_BUILDER_SRC/WUI_SERVER_SRC/ALCHEMY_OBJECTS_SRC/OOREXX_CRYPTO_SRC)'
fi
if [[ -n "${FBM_REXX:-}" && -n "${WUI_SERVER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" && -n "${OOREXX_CRYPTO_SRC:-}" && -n "${FBM_BANK_SRC:-}" && -n "${FBM_RISK_SRC:-}" && -n "${FBM_ACCOUNTING_SRC:-}" && -n "${ACCOUNTING_CORE_SRC:-}" && -n "${JOURNAL_POINTED_STATE_SRC:-}" ]]; then
  export REXX_PATH="$ROOT/integration:$ROOT/tests:$FBM_BANK_SRC:$FBM_RISK_SRC:$FBM_ACCOUNTING_SRC:$ACCOUNTING_CORE_SRC:$JOURNAL_POINTED_STATE_SRC:$WUI_SERVER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$(dirname "$FBM_REXX")${REXX_PATH:+:$REXX_PATH}"
  (cd "$ROOT" && "$FBM_REXX" "$ROOT/tests/test_authority_projection_adapter.rex")
else
  echo 'Merchant authority projection test: SKIP (set FBM_REXX/WUI_SERVER_SRC/ALCHEMY_OBJECTS_SRC/OOREXX_CRYPTO_SRC/FBM_BANK_SRC/FBM_RISK_SRC/FBM_ACCOUNTING_SRC/ACCOUNTING_CORE_SRC/JOURNAL_POINTED_STATE_SRC)'
fi

if [[ -n "${FBM_REXX:-}" && -n "${WUI_SERVER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" && -n "${OOREXX_CRYPTO_SRC:-}" && -n "${OOREXX_QUEUE_FABRIC_SRC:-}" && -n "${WIRE_UI_GATEWAY_ROOT:-}" && -n "${ALCHEMY_WIRE_UI_JS_ROOT:-}" ]]; then
  export REXX_PATH="$ROOT/integration:$ROOT/tests:$WUI_SERVER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$OOREXX_QUEUE_FABRIC_SRC:$WIRE_UI_GATEWAY_ROOT/src:$(dirname "$FBM_REXX")${REXX_PATH:+:$REXX_PATH}"
  node "$ROOT/tests/test_real_browser_rows.mjs"
else
  echo 'Merchant real browser row transport: SKIP (set FBM_REXX/WUI_SERVER_SRC/ALCHEMY_OBJECTS_SRC/OOREXX_CRYPTO_SRC/OOREXX_QUEUE_FABRIC_SRC/WIRE_UI_GATEWAY_ROOT/ALCHEMY_WIRE_UI_JS_ROOT)'
fi
