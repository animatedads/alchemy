#!/bin/sh
# SSC write-side intentions qualification: feasibility discovery + dispatch through the MCP
# authority, on a real store built by the Rexx/SQL SQLite provider, with the real IntentionService.
# Author: Claude (Opus 4.8), 2026-10-24. Architecture: Tom Dyer.
# Dependencies come from the Alchemy repository (ALCHEMY_REPO_ROOT, exported by autobuild).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO=${ALCHEMY_REPO_ROOT:-$(CDPATH= cd -- "$ROOT/../.." && pwd)}
P="$REPO/packages"
SSC="$P/oorexx_semantic_source_store_v0.1-dev28"
RX="$P/oorexx_rexxsql_backend_v0.1"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

# librexxsql.so is required (the store runs on SQLite through Rexx/SQL).
sh "$RX/tools/build_rexxsql.sh" "$WORK/lib"

# No Foreign Runtime: the store's SHA-256 has a pure-ooRexx path and this test does a single
# tiny import, so no native crypto build is needed.
export REXX_PATH="$ROOT/src:$P/oorexx_intention_service/src:$P/oorexx_intention_service/src/nlp:$RX/src:$RX/adapters/ssc:$P/oorexx_native_database_backends_v0.1/src:$SSC/src:$P/alchemy_objects_v0.8/src:$P/oorexx_crypto_v0.8.3/src:$P/runtime_reference_v0.4/src"
export LD_LIBRARY_PATH="$WORK/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rexx "$ROOT/tests/test_write_intentions.rex" "$WORK/db"
echo "SSC WRITE INTENTIONS v0.1 QUALIFICATION: PASS"
