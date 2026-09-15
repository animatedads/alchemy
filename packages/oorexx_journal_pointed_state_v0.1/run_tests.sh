#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for t in tests/test_*.rex; do
  echo "== $t =="
  rexx "$t"
done
