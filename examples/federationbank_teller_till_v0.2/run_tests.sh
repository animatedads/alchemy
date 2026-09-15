#!/usr/bin/env bash
set -euo pipefail
REXX=${REXX:-rexx}
cd "$(dirname "$0")/tests"
for t in test_*.rex; do "$REXX" "$t"; done
