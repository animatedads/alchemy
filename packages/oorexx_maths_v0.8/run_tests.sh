#!/bin/sh
set -eu
REXX_BIN="${REXX_BIN:-rexx}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
"$REXX_BIN" test_core.rex
"$REXX_BIN" test_claims.rex
"$REXX_BIN" test_rational.rex
"$REXX_BIN" test_exact_numbers.rex
"$REXX_BIN" test_decimal_expansion.rex
"$REXX_BIN" test_rational_roundtrip.rex
"$REXX_BIN" test_quantization.rex
"$REXX_BIN" test_mixed_precision.rex
"$REXX_BIN" test_math3d.rex
"$REXX_BIN" test_rational_matrix.rex
"$REXX_BIN" test_proof_planner.rex
if [ "${MATHS_TEST_NUMPY:-1}" = 1 ]; then
  "$REXX_BIN" test_numpy.rex
  "$REXX_BIN" test_proof_planner_numpy.rex
fi
if [ "${MATHS_TEST_PROOF_PROVIDERS:-1}" = 1 ]; then
  PYTHONPATH="$ROOT/python${PYTHONPATH:+:$PYTHONPATH}" "$REXX_BIN" test_proof_providers.rex
  PYTHONPATH="$ROOT/python${PYTHONPATH:+:$PYTHONPATH}" "$REXX_BIN" test_proof_planner_providers.rex
  PYTHONPATH="$ROOT/python${PYTHONPATH:+:$PYTHONPATH}" "$REXX_BIN" test_flint_provider.rex
fi
if [ "${MATHS_TEST_CRYPTO:-0}" = 1 ]; then
  if [ "${MATHS_TEST_CRYPTO_FOREIGN:-0}" = 1 ]; then
    "$REXX_BIN" test_crypto_evidence_foreign.rex
  else
    "$REXX_BIN" test_crypto_evidence.rex
  fi
fi
