#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REXX="${REXX:-rexx}"
REXXC="${REXXC:-rexxc}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"

for f in src/OdooDynamicObject.cls src/OdooCRMProvider.cls src/OdooApiClientTransport.cls; do
  "$REXXC" "$f"
done

for t in tests/test_dynamic_object.rex tests/test_provider.rex tests/test_relation_graph.rex tests/test_model_space.rex tests/test_live_query.rex; do
  "$REXX" "$t"
done
"$REXX" tests/test_identity_map.rex
