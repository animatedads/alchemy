#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:?set OOREXX_HOME to extracted/installed ooRexx prefix, e.g. /usr/local}"
: "${WIRE_UI_BUILDER_ROOT:?set WIRE_UI_BUILDER_ROOT to wire_ui_builder_v0.11}"
: "${WIRE_UI_SERVER_ROOT:?set WIRE_UI_SERVER_ROOT to wire_ui_server_v0.17}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.8}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to oorexx_crypto_v0.5}"
export PATH="$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
COMMON="$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src:$OOREXX_HOME/bin"
export REXX_PATH="$ROOT/wire_ui:$WIRE_UI_BUILDER_ROOT/src:$COMMON"
rexx "$ROOT/tests/test_builder_release.rex"
rexx "$ROOT/tools/build_vmm_operator_release.rex" /tmp/vmm-operator-release.json >/tmp/vmm-operator-build.out
cmp -s /tmp/vmm-operator-release.json "$ROOT/compiled/vector_meridian_markets_operations_v0.2.json"
rm -f /tmp/vmm-operator-release.json /tmp/vmm-operator-build.out
export REXX_PATH="$WIRE_UI_SERVER_ROOT/src:$COMMON"
cd "$ROOT"
rexx "$ROOT/tests/test_server_action_authority.rex"
echo 'VECTOR MERIDIAN MARKETS WIRE UI WEB v0.2 QUALIFICATION: PASS'
