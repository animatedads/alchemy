#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${REXX_BIN:?Set REXX_BIN to exact ooRexx r13196 executable}"
: "${REXX_PATH:?REXX_PATH must include dev17, LDAP Identity dev22, RPC core dev1 and Grid dev15 dependency directories}"
"$REXX_BIN" "$ROOT/tests/test_grid_ldap_identity_authorization.rex"
"$REXX_BIN" "$ROOT/tests/test_grid_authorized_service_rpc.rex"
python3 -m unittest discover -s "$ROOT/tests" -p test_identity_contract_static.py -v
