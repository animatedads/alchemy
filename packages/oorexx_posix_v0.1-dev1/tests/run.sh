#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
export REXX_PATH="$root/src:$root/src/providers${REXX_PATH:+:$REXX_PATH}"
cd "$here"
for t in test_smoke.rex test_failures.rex test_xattr_contract.rex test_directory_names.rex; do
  echo "== $t =="
  "$REXX_BIN" "$t"
done
