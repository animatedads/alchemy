#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
: "${REXX:=rexx}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to ooRexx Crypto src directory}"
: "${API_CLIENT_SRC:?set API_CLIENT_SRC to ooRexx API Client src directory}"
: "${WLU_SRC:?set WLU_SRC to Work Load Units src directory}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to Alchemy Objects src directory}"
: "${SECURITY_SRC:?set SECURITY_SRC to Security Effect src directory}"
: "${LEGAL_SRC:?set LEGAL_SRC to Legal Effect src directory}"
: "${ACCESS_SRC:?set ACCESS_SRC to Access Permissions src directory}"
: "${POLICY_SRC:?set POLICY_SRC to Institutional Policy src directory}"
: "${QUEUE_SRC:?set QUEUE_SRC to Queue Fabric src directory}"
export PATH="$ROOT/src:$CRYPTO_SRC:$API_CLIENT_SRC:$WLU_SRC:$ALCHEMY_SRC:$SECURITY_SRC:$LEGAL_SRC:$ACCESS_SRC:$POLICY_SRC:$QUEUE_SRC:${PATH}"
cd "$HERE"
"$REXX" test_core.rex
"$REXX" test_authority_and_admission.rex
"$REXX" test_wlu_adapter.rex
"$REXX" test_dispatch_envelope.rex
"$REXX" test_authority_adapters.rex
"$REXX" test_queue_fabric_adapter.rex
"$REXX" test_liveness_ownership.rex
"$REXX" test_integrity_binding.rex
"$REXX" test_durable_restart.rex
"$REXX" test_durable_wlu_restart.rex
"$REXX" test_api_client_mesh.rex
