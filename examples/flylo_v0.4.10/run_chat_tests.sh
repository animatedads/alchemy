#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:?set OOREXX_HOME to the ooRexx installation root}"
export OOREXX_BIN="$OOREXX_HOME/bin"
export OOREXX_LIB="$OOREXX_HOME/lib"
export PATH="$OOREXX_BIN:$PATH"
export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/vendor/oorexx_stdlib_5.3.0_r13196:$ROOT/src:$ROOT/vendor/accounting_core_v0.7/src:$ROOT/vendor/oorexx_ai_provider_grok_v0.4/src:$ROOT/vendor/oorexx_ai_access_v0.6/src:$ROOT/vendor/oorexx_secret_broker_v0.2/src:$ROOT/vendor/alchemy_objects_v0.8/src:$ROOT/vendor/oorexx_crypto_v0.5/src:$ROOT/vendor/structured_utterance_v0.3/src:$ROOT/vendor/oorexx_queue_fabric_v0.9-dev4/src:$ROOT/vendor/wire_ui_server_v0.17/src:$ROOT/vendor/wire_ui_builder_v0.11/src:$ROOT/vendor/legal_effect_v0.14/src:$OOREXX_BIN${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"

rm -rf "$ROOT/.test-runtime/chat"
mkdir -p "$ROOT/.test-runtime/chat"
trap 'rm -rf "$ROOT/.test-runtime/chat"' EXIT

echo "=== vendored structured-runtime JSON preflight ==="
"$OOREXX_BIN/rexx" tools/flylo_runtime_probe.rex

echo "=== Structured language / utterance contract ==="
"$OOREXX_BIN/rexx" tests/test_structured_language.rex

echo "=== Post-booking travel-information authority ==="
"$OOREXX_BIN/rexx" tests/test_travel_information.rex

echo "=== larger-party assistant / inventory boundary ==="
"$OOREXX_BIN/rexx" tests/test_assistant_large_party.rex

echo "=== Structured Grok interpretation/generation boundary ==="
"$OOREXX_BIN/rexx" tests/test_structured_grok_boundary.rex

echo "=== Grok explanation authority boundary ==="
"$OOREXX_BIN/rexx" tests/test_grok_boundary.rex

echo "=== Grok conversational prompt boundary ==="
"$OOREXX_BIN/rexx" tests/test_grok_chat_assistant.rex

echo "=== launcher baseline ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/launcher" node tests/test_launcher.mjs

echo "=== ./flylo -> Grok real-time fixture ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/assistant" FLYLO_TEST_REXX="$OOREXX_BIN/rexx" FLYLO_TEST_REXX_LIB="$OOREXX_LIB" node tests/test_launcher_assistant.mjs

echo "=== structured booking conversation -> Journey Engine ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/structured-booking" FLYLO_TEST_REXX="$OOREXX_BIN/rexx" FLYLO_TEST_REXX_LIB="$OOREXX_LIB" node tests/test_launcher_structured_booking.mjs

echo "=== post-booking ancillary + entry/customs conversation ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/postbooking" FLYLO_TEST_REXX="$OOREXX_BIN/rexx" FLYLO_TEST_REXX_LIB="$OOREXX_LIB" node tests/test_launcher_postbooking_assistant.mjs

echo "=== ordinary passenger intents are release blockers ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/common-intents" FLYLO_TEST_REXX="$OOREXX_BIN/rexx" FLYLO_TEST_REXX_LIB="$OOREXX_LIB" node tests/test_launcher_common_intents.mjs

echo "=== larger-party chat -> inventory authority ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/large-party" FLYLO_TEST_REXX="$OOREXX_BIN/rexx" FLYLO_TEST_REXX_LIB="$OOREXX_LIB" node tests/test_launcher_large_party.mjs

echo "=== internal structured-runtime conditions degrade helpfully ==="
FLYLO_DATA_DIR="$ROOT/.test-runtime/chat/internal-continuity" node tests/test_launcher_internal_continuity.mjs

echo "=== no Batch runtime in passenger chat ==="
if find vendor -type f -iname '*Batch*' -print -quit | grep -q .; then
  echo "FAIL: Batch runtime source present under vendor" >&2
  exit 71
fi
if grep -R -E 'GrokBatchProvider|GrokBatchWLU|/v1/batches' flylo tools src web >/dev/null 2>&1; then
  echo "FAIL: passenger chat references Grok Batch" >&2
  exit 72
fi
echo "PASS no Grok Batch passenger runtime"

echo "=== no mutable ooRexx RESULT locals in assistant bridges ==="
if grep -nEi '^[[:space:]]*result[[:space:]]*=[[:space:]]*\.directory' src/FlyLoAssistantOrchestrator.cls tools/flylo_assistant_turn.rex >/dev/null 2>&1; then
  echo "FAIL: mutable special RESULT variable found in assistant bridge/orchestrator" >&2
  exit 73
fi
echo "PASS no mutable RESULT locals"

echo "=== source / browser syntax ==="
"$OOREXX_BIN/rexxc" src/FlyLoGrokAssistant.cls >/dev/null
"$OOREXX_BIN/rexxc" src/FlyLoStructuredLanguage.cls >/dev/null
"$OOREXX_BIN/rexxc" src/FlyLoAssistantOrchestrator.cls >/dev/null
"$OOREXX_BIN/rexxc" src/FlyLoTravelInformation.cls >/dev/null
"$OOREXX_BIN/rexxc" src/FlyLoGrokStructuredProvider.cls >/dev/null
"$OOREXX_BIN/rexxc" tools/flylo_assistant_turn.rex >/dev/null
"$OOREXX_BIN/rexxc" tools/flylo_runtime_probe.rex >/dev/null
node --check flylo
node --check web/flylo.js

echo "FlyLo v0.4.10 structured servicing/chat qualification: PASS"
