#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX:=rexx}"
cd "$ROOT/tests"
for t in test_codec.rex test_path.rex test_endpoint_rw.rex test_endpoint_dir.rex test_mutations.rex test_registry_integration.rex test_bounds.rex test_framer.rex; do
  "$REXX" "$t"
done
