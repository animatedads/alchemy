#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
: "${INTENTION_SERVICE_ROOT:?INTENTION_SERVICE_ROOT must name the sibling ooRexx Intention Service package}"
: "${LEGAL_EFFECT_ROOT:?LEGAL_EFFECT_ROOT must name the sibling Legal Effect v0.14 package}"
: "${ALCHEMY_OBJECTS_ROOT:?ALCHEMY_OBJECTS_ROOT must name the sibling Alchemy Objects package}"
: "${CRYPTO_ROOT:?CRYPTO_ROOT must name the sibling ooRexx Crypto package}"
if [[ -f "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
elif [[ -f "$INTENTION_SERVICE_ROOT/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT"
else
  echo "missing IntentionService.cls under INTENTION_SERVICE_ROOT=$INTENTION_SERVICE_ROOT" >&2
  exit 2
fi
if [[ ! -f "$LEGAL_EFFECT_ROOT/src/LegalEffect.cls" ]]; then
  echo "missing LegalEffect.cls under LEGAL_EFFECT_ROOT=$LEGAL_EFFECT_ROOT" >&2
  exit 2
fi
if [[ ! -f "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" ]]; then
  echo "missing AlchemyObject.cls under ALCHEMY_OBJECTS_ROOT=$ALCHEMY_OBJECTS_ROOT" >&2
  exit 2
fi
if [[ ! -f "$CRYPTO_ROOT/src/crypto.cls" ]]; then
  echo "missing crypto.cls under CRYPTO_ROOT=$CRYPTO_ROOT" >&2
  exit 2
fi
export REXX_PATH="$ROOT/src:$ROOT/tests:$INTENTION_SRC:$INTENTION_SRC/nlp:$LEGAL_EFFECT_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
python3 tests/test_legal_effect_v014_contract.py
"$REXX_BIN" tests/test_legal_interrogation.rex
"$REXX_BIN" tests/test_intention_port.rex
"$REXX_BIN" tests/test_lifecycle.rex
"$REXX_BIN" tests/test_dev11_discovery.rex
"$REXX_BIN" tests/test_intention_service_dev11_live.rex
"$REXX_BIN" tests/test_legal_effect_v014_live.rex
printf '%s\n' 'LEGAL INTERROGATION DEV6 TESTS: PASS'
