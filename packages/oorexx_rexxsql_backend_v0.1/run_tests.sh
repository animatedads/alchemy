#!/bin/sh
# Rexx/SQL backend qualification: build, driver, backend contract, Semantic Source Store suites.
# Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
# Dependencies come from the Alchemy repository (ALCHEMY_REPO_ROOT, exported by autobuild).
# Needs: gcc, make, patch (or git), SQLite 3 headers and library, ooRexx 4.0+ headers and library.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(CDPATH= cd -- "$ROOT/../.." && pwd)}
P="$REPO/packages"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "== build librexxsql.so (Rexx/SQL 2.6B3 + upstream/patches)"
sh "$ROOT/tools/build_rexxsql.sh" "$WORK/lib"

echo "== driver"
mkdir "$WORK/driver"
LD_LIBRARY_PATH="$WORK/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" rexx "$ROOT/tests/test_rexxsql_driver.rex" "$WORK/driver"

echo "== backend contract"
mkdir "$WORK/backend"
LD_LIBRARY_PATH="$WORK/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
REXX_PATH="$ROOT/src:$P/oorexx_native_database_backends_v0.1/src" \
  rexx "$ROOT/tests/test_rexxsql_backend.rex" "$WORK/backend"

SSC="$P/oorexx_semantic_source_store_v0.1-dev28"
if [ -d "$SSC/src" ]; then
  echo "== SSC provider selection (store chosen by provider id)"
  mkdir "$WORK/provsel"
  LD_LIBRARY_PATH="$WORK/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  REXX_PATH="$ROOT/src:$ROOT/adapters/ssc:$P/oorexx_native_database_backends_v0.1/src:$SSC/src" \
    rexx "$ROOT/tests/test_ssc_provider_selection.rex" "$WORK/provsel"
fi

SSC="$P/oorexx_semantic_source_store_v0.1-dev28"
if [ -d "$SSC/test_live" ]; then
  echo "== Semantic Source Store live suites on Rexx/SQL"
  if [ -z "${FOREIGN_RUNTIME_ROOT:-}" ]; then
    cp -r "$P/oorexx_foreign_runtime_v0.22.6" "$WORK/fr"
    make -s -C "$WORK/fr" build/libforeign_runtime.so >/dev/null
    FOREIGN_RUNTIME_ROOT="$WORK/fr"
  fi
  ALCHEMY_REPO_ROOT="$REPO" FOREIGN_RUNTIME_ROOT="$FOREIGN_RUNTIME_ROOT" \
    sh "$ROOT/adapters/ssc/run_ssc_live_on_rexxsql.sh" "$SSC" "$WORK/lib"
else
  echo "SKIP Semantic Source Store suites: $SSC not present"
fi
echo "REXXSQL BACKEND v0.1 QUALIFICATION: PASS"
