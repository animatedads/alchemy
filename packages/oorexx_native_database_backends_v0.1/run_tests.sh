#!/bin/sh
set -eu
: "${DB_CORE_ROOT:?set DB_CORE_ROOT to oorexx_db_skeleton_v0_46 root}"
: "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to oorexx_foreign_runtime_v0.22.2 root}"
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export NATIVE_DB_ROOT="$ROOT"
export REXX_PATH="$ROOT/src:$ROOT/postgres:$DB_CORE_ROOT:$FOREIGN_RUNTIME_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rexx "$ROOT/tests/test_capability_model.rex"
rexx "$ROOT/tests/test_postgres_native_offline.rex"
rexx "$ROOT/tests/test_postgres_dbcore_adapter.rex"
rexx "$ROOT/tests/test_postgres_fallback_contract.rex"

if [ -n "${NOSQLSERVER_ROOT:-}" ]; then
  : "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT when NOSQLSERVER_ROOT is set}"
  : "${CRYPTO_ROOT:?set CRYPTO_ROOT when NOSQLSERVER_ROOT is set}"
  export REXX_PATH="$ROOT/src:$ROOT/gis:$NOSQLSERVER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_ROOT:$REXX_PATH"
  rexx "$ROOT/tests/test_geopackage_oorexx_backend.rex"
fi
