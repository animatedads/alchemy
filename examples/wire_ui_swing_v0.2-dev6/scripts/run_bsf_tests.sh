#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_LOCAL:?set OOREXX_LOCAL to extracted ooRexx /usr/local root}"
: "${BSF4OOREXX_HOME:?set BSF4OOREXX_HOME to extracted bsf4oorexx root}"
: "${BSF4OOREXX_LOCAL_LIB:?set BSF4OOREXX_LOCAL_LIB to directory containing libBSF4ooRexx850.so}"
JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}" 
export PATH="$OOREXX_LOCAL/bin:$PATH"
"$ROOT/scripts/build.sh"
export LD_LIBRARY_PATH="$BSF4OOREXX_LOCAL_LIB:$OOREXX_LOCAL/lib:$JAVA_HOME/lib/server:${LD_LIBRARY_PATH:-}"
export CLASSPATH="$BSF4OOREXX_HOME/lib/bsf4ooRexx-v850-20260326-bin.jar:$ROOT/build/wire-ui-swing-v0.2-dev6.jar${CLASSPATH:+:$CLASSPATH}"
export REXX_PATH="$ROOT/integration:$BSF4OOREXX_HOME${REXX_PATH:+:$REXX_PATH}"
export BSF4Rexx_JavaStartupOptions="${BSF4Rexx_JavaStartupOptions:--Djava.awt.headless=true}"
rexx "$ROOT/integration/test_bsf_bridge.rex"
rexx "$ROOT/integration/test_bsf_roundtrip.rex"
if [[ -n "${WIRE_UI_SERVER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" && -n "${OOREXX_CRYPTO_SRC:-}" ]]; then
  export REXX_PATH="$ROOT/integration:$WIRE_UI_SERVER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$BSF4OOREXX_HOME${REXX_PATH:+:$REXX_PATH}"
  rexx "$ROOT/integration/test_server_v017_contract.rex"
  rexx "$ROOT/integration/test_server_v017_workspace_context.rex"
else
  echo "SKIP server v0.17 contract: set WIRE_UI_SERVER_SRC, ALCHEMY_OBJECTS_SRC and OOREXX_CRYPTO_SRC"
fi
if [[ -n "${WIRE_UI_BUILDER_SRC:-}" && -n "${ALCHEMY_OBJECTS_SRC:-}" && -n "${OOREXX_CRYPTO_SRC:-}" ]]; then
  export REXX_PATH="$ROOT/integration:$WIRE_UI_BUILDER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$BSF4OOREXX_HOME${REXX_PATH:+:$REXX_PATH}"
  rexx "$ROOT/integration/test_builder_v011_contract.rex"
else
  echo "SKIP Builder v0.11 contract: set WIRE_UI_BUILDER_SRC, ALCHEMY_OBJECTS_SRC and OOREXX_CRYPTO_SRC"
fi
