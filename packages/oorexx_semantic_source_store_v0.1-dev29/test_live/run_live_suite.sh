#!/bin/sh
# Semantic Source Store v0.1-dev26 live qualification (real NoSQLServer, Foreign Runtime crypto, no stubs).
# Author: Claude (Opus 5.5), 2026-10-23. Architecture: Tom Dyer.
# Dependencies are taken from the Alchemy repository (ALCHEMY_REPO_ROOT, exported by autobuild).
# Set SSC_DOGFOOD_ZIP to also import a real package ZIP and rebuild every ooRexx file byte-for-byte.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(cd "$HERE/../../.." && pwd)}
P="$REPO/packages"
for d in nosqlserver_v0.79/src alchemy_objects_v0.8/src oorexx_crypto_v0.8.3/src runtime_reference_v0.4/src oorexx_foreign_runtime_v0.22.6 oorexx_intention_service/src; do
  [ -e "$P/$d" ] || { echo "missing dependency: packages/$d" >&2; exit 2; }
done
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
if [ -z "${FOREIGN_RUNTIME_ROOT:-}" ]; then
  cp -r "$P/oorexx_foreign_runtime_v0.22.6" "$WORK/fr"
  make -s -C "$WORK/fr" build/libforeign_runtime.so >/dev/null
  FOREIGN_RUNTIME_ROOT="$WORK/fr"
fi
export REXX_PATH="$HERE/../src:$P/nosqlserver_v0.79/src:$P/alchemy_objects_v0.8/src:$P/oorexx_crypto_v0.8.3/src:$P/runtime_reference_v0.4/src:$FOREIGN_RUNTIME_ROOT/rexx"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SSC_FAST_CRYPTO=1
cd "$HERE"
SSC_TEST_DB="$WORK/db1" rexx repository_roundtrip_test.rex
SSC_TEST_DB="$WORK/db2" rexx mcp_operations_test.rex
if [ -n "${SSC_DOGFOOD_ZIP:-}" ]; then SSC_TEST_DB="$WORK/db3" rexx dogfood_bulk_import_test.rex; fi
INTENTION_SERVICE_SRC="$P/oorexx_intention_service/src" REXX_PATH= bash "$HERE/../tools/test_dev25_environment.sh"
echo "SSC STORE v0.1-dev26 LIVE QUALIFICATION: PASS"
rexx "$HERE/semantic_mutation_test.rex"
