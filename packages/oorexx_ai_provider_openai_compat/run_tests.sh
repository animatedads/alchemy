#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${OOREXX_ROOT:?set OOREXX_ROOT}"
: "${AI_ACCESS_ROOT:?set AI_ACCESS_ROOT}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT}"
: "${CRYPTO_ROOT:?set CRYPTO_ROOT}"
export PATH="$OOREXX_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/tests/fixtures:$AI_ACCESS_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
rexx -v | head -3
rexxc src/OpenAICompatProvider.cls >/dev/null
rexxc src/OpenAICompatWLU.cls >/dev/null
rexxc tests/test_auth_modes.rex >/dev/null
rexx tests/test_auth_modes.rex "$HERE"
echo 'ALL PASS'
